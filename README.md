# AEPTarget

<!--
on [![Cocoapods](https://img.shields.io/cocoapods/v/AEPCore.svg?color=orange&label=AEPCore&logo=apple&logoColor=white)](https://cocoapods.org/pods/AEPTarget)
-->
[![SPM](https://img.shields.io/badge/SPM-Supported-orange.svg?logo=apple&logoColor=white)](https://swift.org/package-manager/)
![Target-CI](https://github.com/adobe/aepsdk-target-ios/workflows/Target-CI/badge.svg)
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aepsdk-target-ios/dev.svg?logo=codecov)](https://codecov.io/gh/adobe/aepsdk-target-ios/branch/dev)

## About this project

The `AEPTarget` helps test, personalize, and optimize mobile app experiences based on user behavior and mobile context. You can deliver interactions that engage and convert through iterative testing and rules-based and AI-powered personalization.  

## Requirements
- Xcode 11.0 (or newer)
- Swift 5.1 (or newer)

## Installation

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

```ruby
# Podfile
use_frameworks!

# for app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPTarget'
    pod 'AEPCore'
end
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

To add the AEPTarget Package to your application, from the Xcode menu select:

`File > Swift Packages > Add Package Dependency...`

Enter the URL for the AEPTarget package repository: `https://github.com/adobe/aepsdk-target-ios.git`.

When prompted, specify the Version rule using a specific version range or an exact version.

Alternatively, if your project has a `Package.swift` file, you can add AEPTarget directly to your dependencies:

```
dependencies: [
    .package(url: "https://github.com/adobe/aepsdk-target-ios.git", .upToNextMajor(from: "3.1.1")),
],
targets: [
    .target(name: "YourTarget",
            dependencies: ["AEPTarget"],
	    path: "your/path")
]
```

### Binaries

To generate an `AEPTarget.xcframework`, run the following command:

```
make archive
```

## Development

The first time you clone or download the project, you should run the following from the root directory to setup the environment:

~~~
make pod-install
~~~

Subsequently, you can make sure your environment is updated by running the following:

~~~
make pod-update
~~~

#### Open the Xcode workspace
Open the workspace in Xcode by running the following command from the root directory of the repository:

~~~
make open
~~~

#### Command line integration

You can run all the test suites from command line:

~~~
make test
~~~

## Documentation

Additional documentation for API usage can be found under the [Documentation](Documentation) directory.


## Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.
