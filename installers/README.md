# Installer Instructions

## Prerequisites
1. **Inno Setup**: Download and install from [jrsoftware.org](https://jrsoftware.org/isdl.php).

## Steps to Create Installer

1. **Build the Application**
   Open your terminal in the project root and run:
   ```bash
   flutter build windows
   ```
   This will generate the Release files in `build\windows\x64\runner\Release`.

2. **Compile the Installer**
   - Open `installers\setup.iss` with Inno Setup Compiler.
   - Click **Build > Compile** (or press Ctrl+F9).
   - Alternatively, you can run from command line:
     ```bash
     "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installers\setup.iss
     ```
   
3. **Locate Installer**
   The `life_style_setup.exe` will be created in the `installers` folder.

## Troubleshooting
- If the build fails, run `flutter clean` and try again.
- If Inno Setup can't find files, ensure the `Source` paths in `setup.iss` match your actual build output.
