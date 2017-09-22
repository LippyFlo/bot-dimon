// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "bot-rocks",
    dependencies: [
        .Package(url: "https://github.com/SlackKit/SlackKit.git", majorVersion: 4),
        .Package(url: "https://github.com/Alamofire/Alamofire.git", majorVersion: 4),
        .Package(url: "https://github.com/drmohundro/SWXMLHash.git", majorVersion: 4)
        ]
)
