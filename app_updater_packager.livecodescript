script "App Updater Packager"
/**
Summary: Add `auto update url` to app configuration array.

Description:
In a packaged application `appCheckForUpdates` will use the `auto update url` property. Set that here.
*/
command finalizePackagedAssets pBuildProfile, pPlatform, @xAppA, pAppFolder
  local tURLsA

  if pPlatform is "windows" then
    _autoUpdateURLs pBuildProfile, tURLsA

    put tURLsA["build profile"] & "/update.txt" into xAppA["auto update url"]
    answer xAppA["auto update url"]
  end if
end finalizePackagedAssets


/**
Summary: Replace the [[SPARKLE_URL]] variable in the Info.plist file with the correct url.

*/
command finalizePackageForPlatform pBuildProfile, pPlatform, pAppFolder, pOutputFolder
  local tFile, tData, tBuildProfile, tURL

  switch pPlatform
    case "macos"
      local tAppBundle

      put folders(pOutputFolder) into tAppBundle
      filter tAppBundle with "*.app"

      put pOutputFolder & "/" & tAppBundle & "/Contents/Info.plist" into tFile
      put URL("binfile:" & tFile) into tData

      put pBuildProfile into tBuildProfile
      put tolower(tBuildProfile) into tBuildProfile
      replace space with "_" in tBuildProfile

      ## sparkle URL
      local tURLsA

      _autoUpdateURLs pBuildProfile, tURLsA
      if tURLsA["build profile"] is not empty then
        put tURLsA["build profile"] & "/appcast.xml" into tURL
      end if
      replace "[[SPARKLE_URL]]" with tURL in tData

      put tData into URL("binfile:" & tFile)
      break
  end switch
end finalizePackageForPlatform


/**
Summary: Zip up the Sparkle update for macos. Fill in the update.txt file for Windows.

*/
command packagingComplete pBuildProfile, pOutputFolder
  local tError, tBuildProfile, tFile, tData, tUpdaterFolder, tURLsA
  local tAppExecutable, tAppExecutableName

  set the itemdelimiter to "/"
  put the last item of levureStandaloneFilename() into tAppExecutable
  set the itemDelimiter to "."
  put item 1 of tAppExecutable into tAppExecutableName
  replace space with "%20" in tAppExecutableName

  set the itemdelimiter to "/"

  ## Path to Windows installer in update.txt
  put pBuildProfile into tBuildProfile
      put tolower(tBuildProfile) into tBuildProfile
      replace space with "_" in tBuildProfile
  put pOutputFolder & "/update/update.txt" into tFile
  put URL("file:" & tFile) into tData

  _autoUpdateURLs pBuildProfile, tURLsA

  put tURLsA["build profile"] & "/" & levureAppGet("version") & "-" & levureAppGet("build") & "/release-notes-win.html" into line 4 of tData
  put tURLsA["build profile"] & "/" & tAppExecutableName & "%20" & levureAppGet("version") & "-" & levureAppGet("build") & ".exe" into line 6 of tData

  put tData into URL("file:"& tFile)

  # Create ZIP file for macos updater
  put pOutputFolder & "/update/" & _versionStringForFilenames() into tUpdaterFolder

  if tError is empty then
    local tAppBundle, tCmd

    put pOutputFolder & "/macos/" & tAppExecutable into tAppBundle
    if there is a folder tAppBundle then
      dispatch "packagerCreateAllFoldersInPath" to stack "Levure Framework Application Packager" with tUpdaterFolder, pOutputFolder
      put the result into tError

      put format("cd \"%s\";ditto -ck --rsrc --keepParent \"%s\" \"%s\"", item 1 to -2 of tAppBundle, \
            the last item of tAppBundle, tUpdaterFolder & "/" & the last item of tAppBundle & ".zip") into tCmd
      get shell(tCmd)
      if the result > 0 then
        put it into tError
      end if
    end if
  end if

  if tError is not empty then
    answer error param(0) && tError
  end if
end packagingComplete


/**
Summary: Replace variables within files being copied as part of `copy files` > `app updater`.

*/
command processCopyFilesFile pBuildProfile, @xFiledata, pOutputFolder, pOutputFilename, pFileSettingsA
  local tURLsA

  _autoUpdateURLs pBuildProfile, tURLsA
  _replaceVariables xFiledata, pBuildProfile, tURLsA
end processCopyFilesFile


private command _replaceVariables @xFileData, pBuildProfile, pURLsA
  replace textEncode("[[VERSION]]", "utf8") with levureAppGet("version") in xFileData
  replace textEncode("[[BUILD]]", "utf8") with levureAppGet("build") in xFileData
  replace textEncode("[[ENGINE_VERSION]]", "utf8") with the version & "." & the buildNumber in xFileData
  replace textEncode("[[BUILD_PROFILE]]", "utf8") with tolower(pBuildProfile) in xFileData
  replace textEncode("[[INTERNET_DATE]]", "utf8") with the internet date in xFileData
  replace textEncode("[[ROOT_AUTOUPDATE_URL]]", "utf8") with pURLsA["root"] in xFileData
  replace textEncode("[[BUILD_AUTOUPDATE_URL]]", "utf8") with pURLsA["version"] in xFileData
  replace textEncode("[[BUILDPROFILE_AUTOUPDATE_URL]]", "utf8") with pURLsA["build profile"] in xFileData
  return empty
end _replaceVariables


private command _autoUpdateURLs pBuildProfile, @rURLsA
  local tSettingsA

  put empty into rURLsA
  put empty into rURLsA["root"]
  put empty into rURLsA["build profile"]
  put empty into rURLsA["version"]
  put empty into rURLsA["macos"]

  if levureAppHasProperty("app updater") then
    put levureAppGet("app updater") into tSettingsA

    put tolower(pBuildProfile) into pBuildProfile

    # Auto Update URLs
    put tSettingsA[pBuildProfile]["root auto update url"] into rURLsA["root"]
    if rURLsA["root"] is empty then
      put tSettingsA["all profiles"]["root auto update url"] into rURLsA["root"]
    end if
    if rURLsA["root"] is not empty then
      set the itemdelimiter to "/"

      put rURLsA["root"] & "/" & pBuildProfile into rURLsA["build profile"]
      put rURLsA["build profile"] & "/" & _versionStringForFilenames() into rURLsA["version"]
      put rURLsA["version"] & "/" & the last item of levureStandaloneFilename() & ".zip" into rURLsA["macos"]
    end if
  end if

  return empty
end _autoUpdateURLs


private function _versionStringForFilenames
  return levureAppGet("version") & "-" & levureAppGet("build")
end _versionStringForFilenames
