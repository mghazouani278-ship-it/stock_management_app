# Play Store Release Steps

## 1) Create upload keystore

Run from `mobile_app/android`:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2) Create `key.properties`

Copy `android/key.properties.example` to `android/key.properties` and set real values:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

`key.properties` and `.jks` are ignored by git.

## 3) Build Play Store bundle (AAB)

Run from `mobile_app`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Output:

`build/app/outputs/bundle/release/app-release.aab`
