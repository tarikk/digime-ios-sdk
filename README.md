# digi.me Consent Access iOS SDK

## Purpose
Consent Access (CA) is an API from digi.me that enables you to ask a user for consent to access some of their data. You do this by proposing a contract with the user that spells out what type of data you want, what you will and won't do with it, how long you will retain it and if you will implement the right to be forgotten.

The digi.me SDK depends on digi.me app being installed to enable user initiated authorization of requests. [Get more info](http://devsupport.digi.me/)

## At glance
Call the function `digimeFrameworkInitiateDataRequestWithAppID:contractID:rsaPrivateKeyHex:` to initiate a request for data and implement the delegate functions for notification of progress and receiving the data in JSON format.

## Requirements

- iOS version 10 or higher;
- XCode 8 or higher;
- iPhone 5 device or higher, iPad 4th Gen or higher, iPad Mini 2nd Gen or higher;

## Demo mode using Example app

You can test and run this project in a demo mode. Under the repository name, click Clone or download. Open 'Example' folder and navigate to readme file. [Follow the installation instruction](https://github.com/digime/digime-ios-sdk/tree/master/Example)

## Installation with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like DigiMeFramework in your projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 0.39.0+ is required to build DigiMeFramework 1.0.0+.

#### Podfile

To integrate the DigiMeFramework into your own existing Xcode project using CocoaPods, you have to specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TargetName' do
pod 'DigiMeFramework'
end
```

Then, run the following command:

```bash
$ pod install
```
If you get an error:

```bash
[!] Unable to find a specification for `DigiMeFramework`
```

Run the following command to update your existing master repo and then execute the install command again:

```bash
$ pod repo update master
$ pod install
```

White list the 'digi.me' app in your Info.plist so you can use iOS Custom URL Scheme to call digi.me client app from your application.

```plist
<key>LSApplicationQueriesSchemes</key>
<array>
<string>digime-ca-master</string>
</array>
```

Extend your Info.plist to support a new Custom URL Scheme. This is used for a callback when the digi.me app choses the application that initiated this request.

```plist
<key>CFBundleURLTypes</key>
<array>
<dict>
<key>CFBundleTypeRole</key>
<string>Editor</string>
<key>CFBundleURLName</key>
<string>Consent Access</string>
<key>CFBundleURLSchemes</key>
<array>
<string>digime-ca-XXXXXX</string>
</array>
</dict>
</array>
```
`XXXXXX` - is your application ID given by digi.me Ltd.

Add this line in your .swift class to add a reference to the framework  `import DigiMeFramework`

From this class make a call to the SDK function and bypass your application id, contract id and your private key in hex format.

`digimeFrameworkInitiateDataRequestWithAppID:contractID:rsaPrivateKeyHex:`

Make sure that your class implements `DigiMeFrameworkDelegate`.

One method is required `digimeFrameworkReceiveDataWithFileNames:filesWithContent:filesWithContent:error:` Within this method you will get decrypted JSON data or an error.

Refer to the `DigiMeFramework.h` file for other delegates convenience methods to receive a state or download progress. Also refer to the error codes that maybe returned by the SDK.

Your application delegate must forward the callback from digi.me app to the SDK library.

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {

if(url.scheme?.hasPrefix(kDigiMeFrameworkReceiversURLSchemaPrefix))!
{
DigiMeFramework.sharedInstance().digimeFrameworkApplication(app, open: url, options: options)
}

return true
}
```
## Downloads

- Digi.me for iOS is the main hub for giving permission to download an individual's data to your app. Digi.me for iOS will show the indiviual the contract details and provide a preview of the data that will be shared. The individual must consent to sharing the data. [Download digi.me for iOS here](https://itunes.apple.com/us/app/digi-me/id1234541790)

##
Copyright © 2017 digi.me Ltd. All rights reserved.



