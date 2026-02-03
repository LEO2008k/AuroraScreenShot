# Інструкції для білду Aurora Screenshot

## Проблема

Є проблеми з правами доступу до системних папок. Swift Package Manager не може створити кеш файли.

## Рішення 1: Надати Full Disk Access

1. Відкрийте **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Натисніть **+** і додайте:
   - `/Applications/Utilities/Terminal.app`
   - Або вашу IDE (якщо використовуєте)
3. Перезапустіть Terminal
4. Спробуйте знову:

   ```bash
   cd /Users/levkokravchuk/Documents/Pet_proj/AuroraScreenShot
   ./bundle_app.sh
   ```

## Рішення 2: Видалити .build через Finder

1. Відкрийте Finder
2. Перейдіть до `/Users/levkokravchuk/Documents/Pet_proj/AuroraScreenShot`
3. Натисніть `Cmd+Shift+.` щоб показати приховані файли
4. Перетягніть папку `.build` в Trash
5. Спробуйте білд знову

## Рішення 3: Використати існуючу .app

Якщо білд не працює, можна:

1. Запустити існуючу `AuroraScreenshot.app` (Build 43 від 30 січня)
2. Перевірити чи всі зміни працюють
3. Якщо потрібно оновити - спробуйте білд після перезавантаження Mac

## Створення DMG (після успішного білду)

```bash
cd /Users/levkokravchuk/Documents/Pet_proj/AuroraScreenShot
./create_dmg.sh
```

Це створить `AuroraScreenshot_Installer.dmg` з останньою версією.

## Перевірка версії

Після білду перевірте версію:

```bash
/Users/levkokravchuk/Documents/Pet_proj/AuroraScreenShot/AuroraScreenshot.app/Contents/MacOS/AuroraScreenshot --version
```

Або відкрийте app і перевірте в меню About.

---

**Поточний стан:**

- ✅ Код оновлено до версії 2.0.34
- ✅ CHANGELOG оновлено
- ✅ README та Git налаштовано
- ⚠️ Білд потребує Full Disk Access для Terminal
- ⚠️ DMG не оновлено (використовує стару версію)
