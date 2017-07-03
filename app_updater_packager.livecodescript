script "App Updater Packager"
command finalizePackage pBuildProfile, pOutputFolder
  local tMacAppBundleFolder
  local tFile, tBuildProfile, tURL

  put MacAppBundleFolder(pOutputFolder) into tMacAppBundleFolder

  ## Update plist file
  local tData

  put tMacAppBundleFolder & "/Contents/Info.plist" into tFile
  put URL("binfile:" & tFile) into tData

  put pBuildProfile into tBuildProfile
  put tolower(tBuildProfile) into tBuildProfile
  replace space with "_" in tBuildProfile

  ## sparkle URL
  put "https://www.bluemangolearning.com/download/screensteps/4_0/auto_update/" & tBuildProfile & "/screensteps_appcast.xml" into tURL
  replace "[[SPARKLE_URL]]" with tURL in tData

  put tData into URL("binfile:" & tFile)
  ## End update plist

  ## Path to Windows installer in update.txt
  set the itemDelimiter to "/"
  put pOutputFolder & "/update/update.txt" into tFile
  put URL("file:" & tFile) into tData
  put "https://www.bluemangolearning.com/download/screensteps/4_0/" & \
        tBuildProfile & "/ScreenSteps%20" & levureAppGet("version") & ".exe" into line 6 of tData
  put tData into URL("file:"& tFile)
end finalizePackage


command packagingComplete pBuildProfile, pOutputFolder
  local tError, tUpdaterFolder

  set the itemdelimiter to "/"

  put pOutputFolder & "/update/" & _versionStringForFilenames() into tUpdaterFolder

  if tError is empty then
    local tAppBundle, tCmd

    put pOutputFolder & "/macos/" & the last item of levureStandaloneFilename() into tAppBundle
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


private function MacAppBundleFolder pBuildFolder
  local tMacFolder, tMacApp

  put pBuildFolder & "/macos" into tMacFolder

  put folders(tMacFolder) into tMacApp
  filter tMacApp with "*.app"

  if tMacApp is not empty then
    return tMacFolder & "/" & tMacApp
  else
    return empty
  end if
end MacAppBundleFolder


command processCopyFilesFile pBuildProfile, @xFiledata, pOutputFolder, pOutputFilename, pFileSettingsA
  local tConfigA, tURLsA

  if levureAppHasProperty("app updater") then
    put levureAppGet("app updater") into tConfigA

    _autoUpdateURLs pBuildProfile, tConfigA, tURLsA
    _replaceVariables xFiledata, pBuildProfile, tURLsA
  end if
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


private command _autoUpdateURLs pBuildProfile, pSettingsA, @rURLsA
  put tolower(pBuildProfile) into pBuildProfile

  # Auto Update URLs
  put pSettingsA[pBuildProfile]["root auto update url"] into rURLsA["root"]
  if rURLsA["root"] is empty then
    put pSettingsA["all profiles"]["root auto update url"] into rURLsA["root"]
  end if
  if rURLsA["root"] is not empty then
    set the itemdelimiter to "/"

    put rURLsA["root"] & "/" & pBuildProfile into rURLsA["build profile"]
    put rURLsA["build profile"] & "/" & _versionStringForFilenames() into rURLsA["version"]
    put rURLsA["version"] & "/" & the last item of levureStandaloneFilename() & ".zip" into rURLsA["osx"]
  end if

  return empty
end _autoUpdateURLs


private function _versionStringForFilenames
  return levureAppGet("version") & "-" & levureAppGet("build")
end _versionStringForFilenames
