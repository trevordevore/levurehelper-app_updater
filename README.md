# app_updater helper

Levure helper that provides auto updates for desktop applications on macOS and Windows. To use this helper in your Levure application add it to the list of `helpers` in the `app.yml` file.

## macOS

The macOS implementation uses an external wrapped around Sparkle. When packaging your application a zipped up version of your app will be created that you will upload to your server. Sparkle will download and install this file when an update is available.

### appcast.xml

Sparkle uses the `appcast.xml` file to detect updates. You need to copy the file included with this helper into the folder where supporting build files are stored (e.g. `build files`) and customize it. Here are the default contents:

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
            <enclosure url="[[BUILD_AUTOUPDATE_URL]]/APP-NAME.app.zip"
               sparkle:version="[[BUILD]]"
               sparkle:shortVersionString="[[VERSION]]"
               length="0"
               type="application/octet-stream" />
         </item>
   </channel>
</rss>
```

You need to change the `APP-NAME` string to be the name of your app executable. You may also change the name of the `release-notes.html` file. This is an HTML file that contains the release notes for this update.

## Windows

The Windows implementation uses an approach built in LiveCode. It is comprised of two stack files (*update_dialog.livecode* and *updater.livecode*) and an *update.txt* file. These files work together to download your full Windows installer when an update is available.

These stacks and the update.txt file should be copied into your application's folder where supporting build files are stored (e.g. `build files`). 

Each stack defines a `PackageMe` handler which will placed a compressed version of the stack alongside the stack file. Whenever you make any changes to either stack you should call `PackageMe` and upload the resulting compressed file to your server.

### update.txt

The `update.txt` file will be processed by this helper each time you build your Levure Application. It primarily contains variables that will be replaced based on the version of your app that is being built. There are some one-time changes you will need to make, however. Here are the default file contents:

```
[[VERSION]].[[BUILD]]
[[ENGINE_VERSION]]
[[ROOT_AUTOUPDATE_URL]]/updater.gz
[[ROOT_AUTOUPDATE_URL]]/[[BUILD_PROFILE]]/[[VERSION]]-[[BUILD]]/release-notes-win.html

https://www.YOUR-SERVER.com/download/APP-NAME/APP-VERSION/[[BUILD_PROFILE]]/INSTALLER-NAME[[VERSION]]-[[BUILD]].exe

[[ROOT_AUTOUPDATE_URL]]/update_dialog.gz
```

Before you use `update.txt` for the first time you will need to configure lines 4 and 6. 

Line 4 includes the name of your release notes file. This is a file that contains a description of your release notes in the `htmltext` LiveCode format. You are responsible for generating and uploading this file.

Line 6 is the location where your Windows installer can be found. This helper will fill in the variables `[[..]]`. You need to configure your server name and path to the root folder where your installer lives.

## Levure Configuration

There are a couple of configuration options that need to be added to your `app.yml` file. 

In the `build profiles` > `all profiles` > `copy files` section add an `app updater` key that points to the `appcast.xml` and `update.txt` files for your app.

An `app updater` key is also added at the root level and tells this helper where the root folder for auto updates is located.

```
build profiles:
  all profiles:
    copy files:
      app updater:
        - filename: ../build files/appcast.xml
        - filename: ../build files/update.txt

app updater:
  all profiles:
    root auto update url: https://www.MY-SERVER.com/download/MY-APP/MY-APP-VERSION/auto_update
```

## Updating Info.plist on macOS

On macOS you will need to customize the Info.plist file and add the following key/value:

```
<key>SUFeedURL</key>
<string>[[SPARKLE_URL]]</string>
```

During the packaging process Levure will replace `[[SPARKLE_URL]]` with the appcast.xml url.

## Packaging your application

When you package an application an `update` folder will be added to the output folder (sits alongside a `macos` or `windows` folder). The `update` folder will contain one folder and two files:

```
./update/1.0.0-10
./update/appcast.xml
./update/update.txt
```

The folder is named after the version of your app and contains the zipped version of your app for macOS. You should add your release note(s) HTML files to this folder as well.

## Uploading your updates

After packaging your application you need to upload files to the correct location. Let's assume that the `root auto update url` defined in the `app.yml` file for your app is `http://www.my-server.com/download/my-app/1_0/auto_update`, that you packaged your application for the `release` build profile, and that you packaged version `1.0.0-10`.

On your server the `auto_update` folder should have a `release` folder inside of it. This represents the build profile. You will upload the `./update/1.0.0-10` folder to this folder first.

After the `1.0.0-10` folder has been uploaded you can upload  the `appcast.xml` and `update.txt` files to the `./update/release` folder. Your update will now be live. You should now have urls similar to the following:

- http://www.my-server.com/download/my-app/1_0/auto_update/release/appcast.xml
- http://www.my-server.com/download/my-app/1_0/auto_update/release/update.txt
- http://www.my-server.com/download/my-app/1_0/auto_update/release/1.0.0-10/myapp.app.zip
- http://www.my-server.com/download/my-app/1_0/auto_update/release/1.0.0-10/release-notes.html
- http://www.my-server.com/download/my-app/1_0/auto_update/release/1.0.0-10/release-notes-win.html

