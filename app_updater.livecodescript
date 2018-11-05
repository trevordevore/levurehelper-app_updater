script "AppUpdater"
local sUpdateIsAvailable = "false"
local sPerformingUpdate = "false"
local sInitialized = "false"
local sReadyToUse = "false"


on libraryStack
  if the target is not me then pass libraryStack

  if the environment is "standalone application" then
    if the platform is "macos" then
      set the revLibraryMapping["sparkle"] to "./Externals/Sparkle.framework"
    else if the platform is "win32" then
      set the revLibraryMapping["winsparkle"] to "./Externals/WinSparkle.dll"
    end if
  end if
end libraryStack


/**
Summary: Call before setting any updater properties.

Description:
This handler will perform any initialization required for the updater library being used
and will assign any default properties configured in `app.yml`. After calling this handler
you can safely set properties before calling `appupdaterRun`.

Returns: empty
*/
command appupdaterInitialize
  if _killUpdater() then return empty

  if the platform is "macos" then
    # Best to store sparkle url in Info.plist. Otherwise the url persists in
    # plist file and affects all builds of an app.
    get sparkleInitialize()
  else if the platform is "win32" then
    local tPath

    get winSparkleSetFeedUrl( levureAppGet("appcast url") )

    put _windowsRegistryPath() into tPath
    if tPath is not empty then
      get winSparkleSetRegistryPath(tPath)
    end if
  end if

  put true into sInitialized

  return empty
end appupdaterInitialize


/**
Summary: Call at the end of `OpenApplication` after you have displayed your application UI.

Description:
This handler will start any automated checks for updates using the current configuration.

Returns: empty
*/
command appupdaterRun
  if _killUpdater() then return empty

  if the platform is "macos" then
    -- get sparkleResetUpdateCycle()
  else if the platform is "win32" then
    get winSparkleInitialize()
  end if

  put true into sReadyToUse

  return empty
end appupdaterRun


/**
Summary: Cleans up after the updater being used.

Description:
Call in `PreShutdownApplication`.

Returns: empty
*/
command appupdaterCleanup
  if _killUpdater() then return empty

  if the platform is "win32" then
    get winSparkleCleanup()
  end if

  return empty
end appupdaterCleanup


/**
Summary: Checks for updates with UI feedback. Use in a Check for Updates... menu item.

Returns: empty
*/
command appupdaterCheckForUpdates
  if _killUpdater() then return empty

  if not sInitialized then appupdaterInitialize
  if not sReadyToUse then appupdaterRun

  if the platform is "macos" then
    get sparkleCheckForUpdates()
  else if the platform is "win32" then
    get winSparkleCheckForUpdates()
  end if

  return empty
end appupdaterCheckForUpdates


/**
Summary: Checks for updates in the background with no UI feedback.

Description:

If you initialize the app updater with automatic update checking then you
don't need to use this handler.

Returns: empty
*/
command appupdaterCheckForUpdatesInBackground
  if _killUpdater() then return empty

  if not sInitialized then appupdaterInitialize
  if not sReadyToUse then appupdaterRun

  if the platform is "macos" then
    get sparkleCheckForUpdatesInBackground()
  else if the platform is "win32" then
    get winSparkleCheckForUpdatesInBackground()
  end if

  return empty
end appupdaterCheckForUpdatesInBackground


/**
Summary: Return whether or not an update is being applied.

Description:
Call this function if your code needs to know if a shutdown was
triggered by the app updater.

Returns: Boolean
*/
function appupdaterPerformingUpdate
  return sPerformingUpdate
end appupdaterPerformingUpdate


/**
Summary: Return whether or not an update is available.

Returns: Boolean
*/
function appupdaterIsUpdateAvailable
  return sUpdateIsAvailable
end appupdaterIsUpdateAvailable


/**
Summary: Returns setting for automatic check for updates.

Description:
On Windows the HKEY_CURRENT_USER root is checked first and then the HKEY_LOCAL_MACHINE
root is checked. If an administrator has set the HKEY_LOCAL_MACHINE root then that
overrides the user settings.

Returns: Boolean
*/
function appupdaterAutomaticallyCheckForUpdates
  if _killUpdater() then return false

  if the platform is "macos" then
    return sparkleAutomaticallyChecksForUpdates()
  else if the platform is "win32" then
    return _windowsCheckForUpdatesSetting()
  else
    return false
  end if
end appupdaterAutomaticallyCheckForUpdates


/**
Summary: Sets whether or not updater should automatically check for updates.

Parameters:

pBoolean: Pass in true to automatically check for updates in the background.

Description:
On Windows this will set the value for the HKEY_CURRENT_USER root.

Returns: nothing
*/
command appupdaterSetAutomaticallyCheckForUpdates pBoolean
   if _killUpdater() then return empty

  if the platform is "macos" then
    get sparkleSetAutomaticallyChecksForUpdates(pBoolean is true)
  else if the platform is "win32" then
    get winSparkleSetAutomaticallyChecksForUpdates(pBoolean is true)
  end if

  return empty
end appupdaterSetAutomaticallyCheckForUpdates


/**
Summary: Return the full registry path used to store auto updater settings on Windows.

Returns: String
*/
function appupdaterWindowsRegistryPath
  return _fullWindowsRegistryPath("user")
end appupdaterWindowsRegistryPath


private function _windowsRegistryPath
  local tPath

  if levureAppHasProperty("app updater") then
    local tSettingsA

    put levureAppGet("app updater") into tSettingsA

    put tSettingsA[levureBuildProfile()]["windows registry path"] into tPath
    if tPath is empty then
      put tSettingsA["all profiles"]["windows registry path"] into tPath
    end if

    if char 1 of tPath is "\" then delete char 1 of tPath
    if the last char of tPath is "\" then delete the last char of tPath
  end if

  return tPath
end _windowsRegistryPath


private function _fullWindowsRegistryPath pType
  local tPath

  put _windowsRegistryPath() into tPath

  if tPath is not empty then
    if pType is "local machine" then
      put "HKEY_LOCAL_MACHINE\" before tPath
    else
      put "HKEY_CURRENT_USER\" before tPath
    end if
  end if

  return tPath
end _fullWindowsRegistryPath


private function _windowsCheckForUpdatesSetting
  local tPath, tBoolean

  put _fullWindowsRegistryPath("user") into tPath

  if tPath is not empty then
    local tMachineSetting

    put queryRegistry(tPath & "\CheckForUpdates") is 1 into tBoolean

    put _fullWindowsRegistryPath("local machine") into tPath
    put queryRegistry(tPath & "\CheckForUpdates") into tMachineSetting

    if tMachineSetting is not empty then
      put tMachineSetting is 1 into tBoolean
    end if
  end if

  return tBoolean
end _windowsCheckForUpdatesSetting


/**
Summary: The updater should not run in dev environment or test mode.

Returns: Boolean
*/
private function _killUpdater
  return the environment is "development" OR levureBuildProfile() is "test"
end _killUpdater


/* CALLBACKS */

/**
Summary: Sent when an update is found. Flag that update is available.
*/
on sparkleFoundUpdate
  put true into sUpdateIsAvailable

  pass sparkleFoundUpdate
end sparkleFoundUpdate


/**
Summary: Sent when an update is found. Flag that update is available.
*/
on sparkleFoundUpdate
  put true into sUpdateIsAvailable

  pass sparkleFoundUpdate
end sparkleFoundUpdate


/**
Summary: Sent when an update is not found. Flag that update is not available.
*/
on sparkleDidNotFindUpdate
  put false into sUpdateIsAvailable

  pass sparkleDidNotFindUpdate
end sparkleDidNotFindUpdate


on sparkleDownloadCanceledByUser

  pass sparkleDownloadCanceledByUser
end sparkleDownloadCanceledByUser


/**
Summary: Callback sent if an error occurs.

Description:
winSparkle doesn't send an error parameter.
*/
on sparkleDidAbortWithError pError
  if pError["description"] is not empty then
    if the last char of pError["description"] is not "." then put "." after pError["description"]
    answer error pError["description"] & cr & cr & "(" & pError["failure reason"] & ")"
  end if
  pass sparkleDidAbortWithError
end sparkleDidAbortWithError


/**
Summary: Callback sent from WinSparkle when the application should quit.
*/
on sparkleShutdownApplication
  quit
end sparkleShutdownApplication


/**
Summary: Callback sent from WinSparkle asking whether or not the relaunch should be postponed.

Description:
This handler is called after the user clicks on the Install Update button in the dialog
that alerts them about an update.

Currently LCB doesn't support returning TRUE/FALSE to WinSparkle because the message is sent on
a different thread. Therefore there is nothing that can be done in this handler.
*/
on sparkleShouldPostponeRelaunchForUpdate
  put true into sPerformingUpdate

  pass sparkleShouldPostponeRelaunchForUpdate
end sparkleShouldPostponeRelaunchForUpdate


/**
Summary: Sent before the app is relaunched. Use this opportunity to save any session data then call sparkleRelaunch to trigger the relaunch.
*/
on sparklePreRelaunchForUpdate
  put true into sPerformingUpdate

  dispatch "PreUpdateApplication" to stack levureAppStackName()
  if it is not "handled" or (it is "handled" and the result is not false) then
    # Continue with relaunch and install after this handler has finished.
    send "__relaunchSparkle" to me in 0 seconds
  end if
end sparklePreRelaunchForUpdate


command __relaunchSparkle
  if the platform is "macos" then
    get sparkleRelaunch()
  end if
end __relaunchSparkle
