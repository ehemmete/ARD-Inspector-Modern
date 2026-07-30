# ARD-Inspector-Modern
A Swift/SwiftUI rewrite of ygini's excellent tool from long ago.   
[Old ARD-Inspector](https://github.com/ygini/ARD-Inspector)

This app allows for reading the Apple Remote Desktop (ARD) preferences file.  I've used it primarily to get the passwords that are saved behind the ARD Master Password.  
On first launch, you will be prompted for the master password and then to find the ARD preferences file.  It is likely at ~/Library/Containers/com.apple.RemoteDesktop/Data/Library/Preferences/com.apple.RemoteDesktop.plist, but might still be at ~/Library/Preferences/com.apple.RemoteDesktop.plist.  
The app will remember where the preferences file is, so you should only have to locate it once.  It can also save the master password in your keychain if you wish.


I had a local LLM do the initial conversion for me as I am not that familiar with Objective-C, and asked it for help on some errors in that conversion.
