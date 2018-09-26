# app_updater helper

Levure helper that provides auto updates for desktop applications on macOS and Windows. To use this helper in your Levure application add it to the list of `helpers` in the `app.yml` file.

LiveCode Requirements: >= 9.0.1 
Sparkle version: 1.20
WinSparkle version: 0.6.0

## macOS

The macOS implementation uses an extension the wraps the [Sparkle](https://sparkle-project.org) framework. 

## Windows

The Windows implementation uses an extension that wraps the [WinSparkle](https://winsparkle.org) DLL.

### appcast.xml

Sparkle and WinSparkle both use an `appcast.xml` file to detect updates. You need to copy the file included with this helper into the folder where supporting build files are stored (e.g. `build files`) and customize it. Here are the default contents:

```
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
   <channel>
      <title>APP-NAME Changelog</title>
      <link>[[BUILDPROFILE_AUTOUPDATE_URL]]/appcast.xml</link>
      <description>Most recent changes.</description>
      <language>en</language>
         <item>
            <title>Version [[VERSION]]</title>
            <sparkle:releaseNotesLink>
              [[BUILD_AUTOUPDATE_URL]]/release-notes.html
            </sparkle:releaseNotesLink>
            <pubDate>[[INTERNET_DATE]]</pubDate>
            <enclosure
               url="https://www.your-company.com/download/your-app/1_0/[[BUILD_PROFILE]]/[[MACOS_INSTALLER_NAME]]%20[[VERSION]]-[[BUILD]].dmg"
               sparkle:version="[[BUILD]]"
               sparkle:shortVersionString="[[VERSION]]"
               length="0"
               type="application/octet-stream" />
            <enclosure
               sparkle:os="windows"
               sparkle:installerArguments="[[WIN_INSTALLER_ARGUMENTS]]"
               url="https://www.your-company.com/download/your-app/1_0/[[BUILD_PROFILE]]/[[WINDOWS_INSTALLER_NAME]]%20[[VERSION]]-[[BUILD]].exe"
               sparkle:version="[[BUILD]]"
               sparkle:shortVersionString="[[VERSION]]"
               length="0"
               type="application/octet-stream" />
         </item>
   </channel>
</rss>

```

You need to change the `APP-NAME` string to be the name of your app executable. You may also change the name of the `release-notes.html` file. This is an HTML file that contains the release notes for this update.

## Levure Configuration

There are a couple of configuration options that need to be added to your `app.yml` file. 

In the `build profiles` > `all profiles` > `copy files` section add the following:

1. An `app updater` key that points to the `appcast.xml` file for your app. 
2. `macos` and `windows` sections that move the `Sparkle.framework` and `WinSparkle.dll` files to their proper locations when packaging a standalone application.

You will also add a `build profiles` entry for `installer name` that tells the auto updater the name of the installers to download.

Lastly, an `app updater` key is also added at the root level. Here you will specify the following:

1. The root url where the appcast.xml and releast-notes.html files will be located. 
2. Command line arguments to pass to the Windows installer. The example shows the arguments you would pass to an installer created with Inno Setup.
3. The registry path where WinSparkle settings will be stored. Do not include the root (e.g. `HKEY_LOCAL_MACHINE\`).

```
build profiles:
  all profiles:
    copy files:
      app updater:
        - filename: ../build files/appcast.xml
      macos: 
        - filename: ./helpers/app_updater/code/x86_64-mac/Sparkle.framework
          destination: ./Externals
      windows:
        - filename: ./helpers/app_updater/code/x86-win32/WinSparkle.dll
          destination: ./Externals
    installer name:
      all platforms: My App
  beta:
    installer name:
      all platforms: My App Beta

app updater:
  all profiles:
    root auto update url: https://www.MY-SERVER.com/download/MY-APP/MY-APP-VERSION/auto_update
    windows installer arguments: /SILENT /SP-
    windows registry path: Software\COMPANY_NAME\PRODUCT_NAME\WinSparkle
```

Note that in addition to the `all platforms` key you can also use `macos` and `windows` keys.

## Updating Info.plist on macOS

On macOS you will need to customize the Info.plist file and add the following key/value pairs to the &lt;dict&gt; node:

```
<key>SUFeedURL</key>
<string>[[SUFeedURL]]</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

During the packaging process Levure will replace `[[SUFeedURL]]` with the appcast.xml url.

## Implementing within Levure

You will need to add some calls to the app updater library in a couple of the messages that Levure dispatches.

1. Within the `InitializeApplication` message call `appupdaterInitialize`.
2. At the end of the `OpenApplication` message call `appupdaterRun`. This should be called after you have displayed your application window.
3. In the `PreShutdownApplication` message call `appupdaterCleanup`.
4. If you have a menu item that is used to check for updates then call `appupdaterCheckForUpdates` from when the menu item is selected.

The auto update helper also adds the `PreUpdateApplication` message that is dispatched to your application right before the application is updated. On macOS you can return return `false` from `PreUpdateApplication` if you would like to cancel the update.

## Packaging your application

When you package an application an `update` folder will be added to the output folder (sits alongside a `macos` or `windows` folder). The `update` folder will contain the appcast.xml file and a folder named after the app version number where your release notes can go.

```
./update/appcast.xml
./update/1.0.0-15
```

### IMPORTANT

There is a bug in the LiveCode 9.0.1 (and previous versions as well) standalone builder that creates a broken copy of the Sparkle.framework bundle. The bug report can be found here:

https://quality.livecode.com/show_bug.cgi?id=19550

Until it is fixed there is a plugin available which installs the necessary script changes for the current IDE session. Download the following LiveCode plugin and place it in your User Extensions `plugins` folder:

http://www.bluemangolearning.com/download/revolution/plugins/InstallRevSaveAsStandaloneScriptUpdate.zip

Before packaging your Levure application select the `InstallRevSaveAsStandaloneUpdate` stack from the `Development` > `Plugins` menu in the LiveCode IDE. You won't see any visible changes but you can then call the `levurePackageApplication` command and the updated scripts will be used.

## Uploading your updates

**Important!** Before you upload the `appcast.xml` file make sure you have uploaded your new installers.

After packaging your application you need to upload files to the correct location. Let's assume that the `root auto update url` defined in the `app.yml` file for your app is `http://www.my-server.com/download/my-app/1_0/auto_update`, that you packaged your application for the `release` build profile, and that you packaged version `1.0.0-10` of your application.

On your server the `auto_update` folder should have a `release` folder inside of it. This represents the build profile. Perform the following actions in the order listed:

1. Upload your installers.
2. Upload the `1.0.0-10` folder to the `./auto_update/release` folder.
3. Upload your `release_notes.html` file to the `./auto_update/release/1.0.0-10` folder.
4. Upload the `appcast.xml` file to the `./auto_update/release` folder.

You should now have urls similar to the following:

- http://www.my-server.com/download/my-app/1_0/auto_update/release/appcast.xml
- http://www.my-server.com/download/my-app/1_0/auto_update/release/1.0.0-10/release-notes.html
