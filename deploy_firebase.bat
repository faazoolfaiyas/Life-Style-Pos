@echo off
echo ==================================================
echo Firebase Authentication and Deployment Tool
echo ==================================================
echo.
echo Step 1: Logging in to Firebase...
echo A browser window will open. Please sign in with your Google account.
echo.
"C:\Users\User\AppData\Local\Microsoft\WinGet\Packages\Google.FirebaseCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\firebase.exe" login
echo.
echo Step 2: Deploying to Firebase Hosting...
echo.
"C:\Users\User\AppData\Local\Microsoft\WinGet\Packages\Google.FirebaseCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\firebase.exe" deploy --only hosting
echo.
echo ==================================================
echo Deployment Finished! You can close this window.
echo ==================================================
pause
