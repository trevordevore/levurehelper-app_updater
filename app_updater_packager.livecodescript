script "App Updater Packager"
/**
Summary: Add `auto update url` to app configuration array.

Description:
In a packaged application `appCheckForUpdates` will use the `auto update url` property. Set that here.
*/
command finalizePackagedAssets pBuildProfile, pPlatform, @xAppA, pAppFolder
  local tUpdateVarsA

  _autoUpdateVariables pBuildProfile, tUpdateVarsA

  put tUpdateVarsA["build profile"] & "/appcast.xml" into xAppA["appcast url"]
end finalizePackagedAssets


/**
Summary: Replace the [[SUFeedURL]] variable in the Info.plist file with the correct url.

*/
command finalizePackageForPlatform pBuildProfile, pPlatform, pAppA, pAppFolder, pOutputFolder
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
      replace "[[SUFeedURL]]" with pAppA["appcast url"] in tData

      put tData into URL("binfile:" & tFile)
      break
  end switch
end finalizePackageForPlatform


/**
Summary: Create folder where release_notes.html file goes

Description:
Create a folder that has the right name for uploading. Don't make the
developer guess.

*/
command packagingComplete pBuildProfile, pOutputFolder
  local tUpdaterFolder

  put pOutputFolder & "/update/" & _versionStringForFilenames() into tUpdaterFolder
  dispatch "packagerCreateAllFoldersInPath" to stack "Levure Framework Application Packager" \
        with tUpdaterFolder, pOutputFolder
end packagingComplete


/**
Summary: Replace variables within files being copied as part of `copy files` > `app updater`.

*/
command processCopyFilesFile pBuildProfile, @xFiledata, pOutputFolder, pOutputFilename, pFileSettingsA
  local tUpdateVarsA

  _autoUpdateVariables pBuildProfile, tUpdateVarsA
  _replaceVariables xFiledata, pBuildProfile, tUpdateVarsA
end processCopyFilesFile


private command _replaceVariables @xFileData, pBuildProfile, pURLsA
  replace textEncode("[[ROOT_AUTOUPDATE_URL]]", "utf8") with pURLsA["root"] in xFileData
  replace textEncode("[[BUILD_AUTOUPDATE_URL]]", "utf8") with pURLsA["version"] in xFileData
  replace textEncode("[[BUILDPROFILE_AUTOUPDATE_URL]]", "utf8") with pURLsA["build profile"] in xFileData
  replace textEncode("[[VERSION]]", "utf8") with levureAppGet("version") in xFileData
  replace textEncode("[[BUILD]]", "utf8") with levureAppGet("build") in xFileData
  replace textEncode("[[ENGINE_VERSION]]", "utf8") with the version & "." & the buildNumber in xFileData
  replace textEncode("[[BUILD_PROFILE]]", "utf8") with rawURLEncode(tolower(pBuildProfile)) in xFileData
  replace textEncode("[[INTERNET_DATE]]", "utf8") with the internet date in xFileData
  replace textEncode("[[WIN_INSTALLER_ARGUMENTS]]", "utf8") with pURLsA["windows installer arguments"] in xFiledata
  replace textEncode("[[MACOS_INSTALLER_NAME]]", "utf8") with rawURLEncode(pURLsA["macos installer name"]) in xFiledata
  replace textEncode("[[WINDOWS_INSTALLER_NAME]]", "utf8") with rawURLEncode(pURLsA["windows installer name"]) in xFiledata
  return empty
end _replaceVariables


private command _autoUpdateVariables pBuildProfile, @rURLsA
  local tSettingsA

  put empty into rURLsA
  put empty into rURLsA["root"]
  put empty into rURLsA["build profile"]
  put empty into rURLsA["version"]
  put empty into rURLsA["macos"]
  put empty into rURLsA["windows installer"]

  put levureAppGet("app updater", true) into tSettingsA

  put tolower(pBuildProfile) into pBuildProfile

  put tSettingsA[pBuildProfile]["root auto update url"] into rURLsA["root"]
  if rURLsA["root"] is empty then
    put tSettingsA["all profiles"]["root auto update url"] into rURLsA["root"]
  end if
  if rURLsA["root"] is not empty then
    set the itemdelimiter to "/"

    put rURLsA["root"] & "/" & rawURLEncode(pBuildProfile) into rURLsA["build profile"]
    put rURLsA["build profile"] & "/" & _versionStringForFilenames() into rURLsA["version"]
  end if

  put tSettingsA[pBuildProfile]["windows installer arguments"] into rURLsA["windows installer arguments"]
  if rURLsA["windows installer arguments"] is empty then
    put tSettingsA["all profiles"]["windows installer arguments"] into rURLsA["windows installer arguments"]
  end if

  local tProfilesA, tDefaultName

  put levureAppGet("build profiles") into tProfilesA

  put tProfilesA[pBuildProfile]["installer name"]["all platforms"] into tDefaultName
  if tDefaultName is empty then
    put tProfilesA["all profiles"]["installer name"]["all platforms"] into tDefaultName
  end if

  put tProfilesA[pBuildProfile]["installer name"]["macos"] into rURLsA["macos installer name"]
  if rURLsA["macos installer name"] is empty then
    put tProfilesA["all profiles"]["installer name"]["macos"] into rURLsA["macos installer name"]
  end if
  if rURLsA["macos installer name"] is empty then
    put tDefaultName into rURLsA["macos installer name"]
  end if

  put tProfilesA[pBuildProfile]["installer name"]["windows"] into rURLsA["windows installer name"]
  if rURLsA["installer name"] is empty then
    put tProfilesA["all profiles"]["installer name"]["windows"] into rURLsA["windows installer name"]
  end if
  if rURLsA["windows installer name"] is empty then
    put tDefaultName into rURLsA["windows installer name"]
  end if

  return empty
end _autoUpdateVariables


private function _versionStringForFilenames
  return levureAppGet("version") & "-" & levureAppGet("build")
end _versionStringForFilenames


-- RFC 1738 compliant
-- http://www.faqs.org/rfcs/rfc1738
function rawURLEncode pString
  put URLEncode(pString) into pString
  replace "+" with "%20" in pString
  replace "*" with "%2A" in pString
  return pString
end rawURLEncode
