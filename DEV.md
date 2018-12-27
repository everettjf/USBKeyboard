
# Develop tips

## macos updater

0. update bundle version +1 +1 +1 , always increment.

0. export to QVKeyboardClient.app

1. directly zip QVKeyboardClient.app to update.zip

2. layout 

~/update/update.zip

3. create local cert by keychain

4. cd tools

./generate_appcast -k ~/Library/Keychains/login.keychain -n 'QVKeyboardUpdater' ~/update

5. upload 

appcast.xml and update.zip to qvkeyboard.github.io/assets/


## dmg

create-dmg QVKeyboardClient.app


