import ArgumentParser
import Foundation
import FitMacCore

@main
@available(macOS 12, *)
struct FitMacCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fitmac",
        abstract: "Make Your Mac Fit Again - A safe, open-source Mac cleaner",
        discussion: """
            FitMac helps you safely free up disk space, uninstall apps completely,
            and manage large files. All operations are transparent and auditable.
            
            Examples:
              fitmac status                    Show disk usage
              fitmac cache --scan              Scan all cache files
              fitmac cache --clean --dry-run   Preview cache cleanup
              fitmac cache --clean             Clean cache files
              fitmac large --min 500MB         Find large files over 500MB
              fitmac uninstall "WeChat"        Find app leftovers
            """,
        subcommands: [StatusCommand.self, CacheCommand.self, TrashCommand.self, LanguageCommand.self, SystemJunkCommand.self, SystemAppCommand.self, iTunesCommand.self, MailCommand.self, DuplicatesCommand.self, HomebrewCommand.self, LargeCommand.self, UninstallCommand.self, LogCommand.self],
        defaultSubcommand: StatusCommand.self
    )
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}

func pad(_ string: String, to length: Int) -> String {
    string.padding(toLength: length, withPad: " ", startingAt: 0)
}

func shortenPath(_ path: String) -> String {
    PathUtils.shorten(path)
}
