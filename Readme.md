#AESBox

AESBox is a simple app that makes it easy to secure your private photos, videos, and other documents without sacrificing the ability to browse through them. AESBox uses industry-standard AES-256 bit encryption—the same encryption the US Government recommends for it’s own top secret material. When you open the app, you’ll be asked to select a folder and provide a password. While this folder is open in AESBox, you can view it’s contents in the app and files you drag in are automatically copied and encrypted with your password.

As you browse your secure files in AESBox, they’re decrypted in memory so you can view them while the contents on disk remain encrypted. Files are only decrypted on disk when you ask AESBox to open them in third party apps.

I wrote AESBox in a weekend because I almost left my laptop at an airport, and realized that my personal identification and private photos could fall into the wrong hands the next time someone swipes it, hacks my Dropbox, or recovers files from an erased drive.

####Features Include:

- Painless securing of photos, videos, and other media using industry-standard encryption.

- Browse encrypted photos and view slideshows without decrypting files on disk.

- No database, no cache, no mess. Easy to use with folders in Dropbox, Box.net and other cloud filesystems.

- Drag and drop files onto the app to copy them into your secure folder and encrypt them.

- Create as many secure folders as you need—just launch the app, select the folder with the encrypted files you want to view, and enter the password you used to encrypt the files.

- Obscure the names of folders inside your secure folder by creating them within the app. Folder 
names are encrypted and are only legible within the app’s browser.

- Change passwords at any time—the app will un-encrypt and re-encrypt your entire secure folder.

- Easily unencrypt a secure folder by switching to an empty password.


####Development & Security Notes:

- Files are protected with industry-standard AES-256bit encryption. There are no salts or modifications to the encryption—files encrypted by AESBox can be easily decrypted by other apps supporting AES-256.

- AESBox adds an “-e” to the file extension of encrypted files so double-clicking them in the Finder will open your secure folder and prompt you for your password.

- When viewing items within the app, files are decrypted on-the-fly for display. Files are only decrypted on disk when AESBox cannot display them and resorts to a third-party app. Decrypted files are stored in your Mac’s temporary items folder and are deleted when the app quits.

- Encryption and decryption uses Apple’s GCD technology to leverage multiple cores. Encrypting hundreds of images only takes a few seconds.