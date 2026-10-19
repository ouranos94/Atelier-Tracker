// swift-tools-version: 5.9
import PackageDescription
import Foundation
let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().path
let package = Package(
    name:"AtelierTracker", platforms:[.macOS(.v14)],
    products:[.executable(name:"AtelierTracker",targets:["AtelierTracker"])],
    targets:[
        .target(name:"COpenMPT",path:"Vendor/OpenMPT",exclude:["lib","LICENSE","licenses"],sources:["bridge.c"],publicHeadersPath:"include",linkerSettings:[.unsafeFlags(["-L",root+"/Vendor/OpenMPT/lib"]),.linkedLibrary("openmpt"),.linkedLibrary("c++")]),
        .target(name:"CAudioMixer",publicHeadersPath:"include"),
        .target(name:"TrackerCore",dependencies:["COpenMPT","CAudioMixer"]),
        .executableTarget(name:"AtelierTracker",dependencies:["TrackerCore"]),
        .testTarget(name:"TrackerCoreTests",dependencies:["TrackerCore"]),
        .testTarget(name:"StudioTests",dependencies:["AtelierTracker","TrackerCore"])
    ])
