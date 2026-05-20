import AppKit
import Foundation

/// Shell execution runs off the main actor so long `waitUntilExit()` calls do not block the UI.
enum ShellExecutor: Sendable {
    nonisolated static func runDetached(
        command cmd: String,
        shellPath: String,
        panel: PanelConfig,
        showOutput: Bool = false,
        workDir: String? = nil
    ) {
        Task.detached(priority: .utility) {
            if showOutput {
                await runStreaming(command: cmd, shellPath: shellPath, panel: panel, workDir: workDir)
            } else {
                await runBatch(command: cmd, shellPath: shellPath, panel: panel, workDir: workDir)
            }
        }
    }

    nonisolated private static func runStreaming(
        command cmd: String,
        shellPath: String,
        panel: PanelConfig,
        workDir: String?
    ) async {
        let process = makeProcess(shellPath: shellPath, command: cmd, workDir: workDir)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let session = await MainActor.run {
            ShellResultPresenter.presentStreaming(command: cmd, panel: panel)
        }

        await MainActor.run {
            session.onCancel = { process.interrupt() }
        }

        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading

        outHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = decode(data)
            Task { @MainActor in session.appendStdout(text) }
        }
        errHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = decode(data)
            Task { @MainActor in session.appendStderr(text) }
        }

        var launchError: String?
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            launchError = error.localizedDescription
        }

        outHandle.readabilityHandler = nil
        errHandle.readabilityHandler = nil

        if let outData = try? outHandle.readToEnd(), !outData.isEmpty {
            await MainActor.run { session.appendStdout(decode(outData)) }
        }
        if let errData = try? errHandle.readToEnd(), !errData.isEmpty {
            await MainActor.run { session.appendStderr(decode(errData)) }
        }

        let code = process.terminationStatus

        await MainActor.run {
            if let launchError {
                fputs("RapidKey: run error: \(launchError)\n", Darwin.stderr)
                session.finish(exitCode: nil, launchError: launchError, style: .failure)
            } else if session.wasCancelled {
                fputs("RapidKey: command cancelled: \(cmd)\n", Darwin.stderr)
                session.finish(exitCode: code, launchError: nil, style: .failure)
            } else if code != 0 {
                fputs("RapidKey: command failed (\(code)): \(cmd)\n", Darwin.stderr)
                session.finish(exitCode: code, launchError: nil, style: .failure)
            } else {
                session.finish(exitCode: code, launchError: nil, style: .output)
            }
        }
    }

    nonisolated private static func runBatch(
        command cmd: String,
        shellPath: String,
        panel: PanelConfig,
        workDir: String?
    ) async {
        let process = makeProcess(shellPath: shellPath, command: cmd, workDir: workDir)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        var launchError: String?
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            launchError = error.localizedDescription
        }

        let outData = try? outPipe.fileHandleForReading.readToEnd()
        let errData = try? errPipe.fileHandleForReading.readToEnd()
        let stdoutText = decode(outData ?? Data())
        let stderrText = decode(errData ?? Data())
        let code = process.terminationStatus

        await MainActor.run {
            if let launchError {
                fputs("RapidKey: run error: \(launchError)\n", Darwin.stderr)
                ShellResultPresenter.present(ShellResultPayload(
                    style: .failure,
                    command: cmd,
                    exitCode: nil,
                    launchError: launchError,
                    stdout: stdoutText,
                    stderr: stderrText
                ), panel: panel)
            } else if code != 0 {
                fputs("RapidKey: command failed (\(code)): \(cmd)\n", Darwin.stderr)
                ShellResultPresenter.present(ShellResultPayload(
                    style: .failure,
                    command: cmd,
                    exitCode: code,
                    launchError: nil,
                    stdout: stdoutText,
                    stderr: stderrText
                ), panel: panel)
            }
        }
    }

    nonisolated private static func makeProcess(
        shellPath: String,
        command: String,
        workDir: String?
    ) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-c", command]
        process.environment = ShellProcessEnvironment.applyingDefaults(shellPath: shellPath)
        if let workDir {
            process.currentDirectoryURL = URL(fileURLWithPath: workDir, isDirectory: true)
        }
        process.standardInput = FileHandle.nullDevice
        return process
    }

    nonisolated private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}
