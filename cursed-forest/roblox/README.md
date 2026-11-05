# 100 дней в Проклятом лесу — проект для Roblox

Код игры на Luau, собирается в файл места Roblox (`.rbxl`) с помощью [Rojo](https://rojo.space). Содержание игры описано в [DESIGN.md](DESIGN.md).

## Состав

```
default.project.json          — карта проекта для Rojo
src/shared/                    — общие модули (ReplicatedStorage.Shared): данные и правила
  Items, Weapons, Armor, Classes, Mobs, World, Loot, Recipes, Config, Remotes
  Inventory.luau, Rules.luau   — чистая логика, проверяется тестами
src/server/                    — сервер (ServerScriptService.Server)
  Main.server.luau             — точка входа
  Services/                    — State, Data (DataStore), WorldBuilder (карта), Camp (костёр, крафт),
                                 Mobs (ИИ, урон, популяции), Combat (оружие), Guardians (Олень и хозяева биомов),
                                 Structures (все постройки и события), PlayerService, TimeService, Drops
src/client/Client.client.luau  — интерфейс и управление
tests/                         — проверки в Lune: синтаксис, логика, содержимое собранного места
tools/check.sh                 — все проверки
tools/publish.sh               — сборка, проверки и публикация через Roblox Open Cloud
```

## Как открыть в Roblox Studio

**Вариант 1, просто посмотреть.** Откройте `build/CursedForest.rbxl` в Roblox Studio (File → Open from File) и нажмите Play.

**Вариант 2, правка с живой синхронизацией.**
1. Установите Rojo: https://rojo.space/docs/v7/getting-started/installation/ (программа и плагин для Studio).
2. В папке проекта выполните `rojo serve`.
3. В Studio откройте пустое место, во вкладке плагина Rojo нажмите Connect.

Чтобы алмазы и классы сохранялись при проверке в Studio, включите Game Settings → Security → Enable Studio Access to API Services. В Studio все классы открыты для проверки, это настраивается флагом `STUDIO_UNLOCK_ALL` в `src/shared/Config.luau`.

## Управление

| Клавиша | Действие |
|---|---|
| ЛКМ, зажать | удар или выстрел |
| 1–9 | выбор оружия |
| E | взаимодействие (подсказки на постройках) |
| F | фонарик или факел |
| R | есть |
| H | бинт |
| G | бросить бомбу, бабахалку или бутылку |
| Q | приручить зверя (флейтист) |

На телефоне те же действия вынесены на экранные кнопки.

## Проверки

```bash
./tools/check.sh
```

Проверяются синтаксис всех файлов, 42 теста логики (мешок, сутки, урон, вулкан, сундуки, корабль, карнавал, лягушки), линтер Selene и сборка места.

## Публикация

```bash
ROBLOX_API_KEY=… ROBLOX_UNIVERSE_ID=… ROBLOX_PLACE_ID=… ./tools/publish.sh
```

`VERSION_TYPE=Saved` сохраняет версию без публикации.
