# setup_dev_env.sh

Bash-скрипт для автоматической настройки рабочего окружения разработчиков на Linux-сервере.

---

## Задание

- Создать группу `dev` и добавить в неё всех «не системных» пользователей (UID ≥ 1000).
- Выдать группе `dev` права sudo без запроса пароля.
- Для каждого пользователя создать директорию `<user_name>_workdir`.
- Путь до директорий задаётся ключом `-d`; если ключ не передан — запрашивается в интерактивном режиме.
- Директории создаются с правами `660` (владелец — пользователь, группа — основная группа пользователя).
- Группе `dev` через ACL выдаётся право **чтения** на каждую директорию.
- Весь лог дублируется в `stdout` **и** в файл `/var/log/setup_dev_env.log`.

---

## Запуск

```bash
# с явным указанием пути
sudo bash setup_dev_env.sh -d /home/workdirs

# без ключа -d (путь будет запрошен интерактивно)
sudo bash setup_dev_env.sh
```

> Скрипт требует прав **root**. Пакет `acl` должен быть установлен для работы с ACL (`apt install acl` / `yum install acl`).

---

## Что делает скрипт — пошагово

| Шаг | Действие |
|-----|----------|
| 1 | Проверяет, что запущен от root |
| 2 | Разбирает аргументы (`-d PATH`), при необходимости запрашивает путь |
| 3 | Создаёт группу `dev` (если не существует) |
| 4 | Находит всех не системных пользователей (`UID 1000–65533` из `/etc/passwd`) |
| 5 | Добавляет каждого из них в группу `dev` через `usermod -aG` |
| 6 | Записывает правило `%dev ALL=(ALL) NOPASSWD: ALL` в `/etc/sudoers.d/dev_nopasswd` и проверяет его через `visudo -c` |
| 7 | Создаёт `<BASE_DIR>/<user>_workdir` для каждого пользователя |
| 8 | Выставляет `chown user:usergroup` + `chmod 660` |
| 9 | Добавляет ACL-запись `g:dev:r-x` через `setfacl` |
| 10 | Все события логирует через `tee` в stdout и `/var/log/setup_dev_env.log` |

---

## Пример вывода

```
[2026-05-23 12:00:01] === setup_dev_env.sh started ===
[2026-05-23 12:00:01] Base directory: /home/workdirs
[2026-05-23 12:00:01] Group 'dev' created.
[2026-05-23 12:00:01] User 'alice' added to group 'dev'.
[2026-05-23 12:00:01] User 'bob' added to group 'dev'.
[2026-05-23 12:00:01] Sudoers rule written: /etc/sudoers.d/dev_nopasswd
[2026-05-23 12:00:01] Base directory '/home/workdirs' created.
[2026-05-23 12:00:01] Directory '/home/workdirs/alice_workdir' created.
[2026-05-23 12:00:01]   permissions: 660  owner: alice  group: alice
[2026-05-23 12:00:01]   ACL: group 'dev' granted read+execute on '/home/workdirs/alice_workdir'.
[2026-05-23 12:00:01] Directory '/home/workdirs/bob_workdir' created.
[2026-05-23 12:00:01]   permissions: 660  owner: bob  group: bob
[2026-05-23 12:00:01]   ACL: group 'dev' granted read+execute on '/home/workdirs/bob_workdir'.
[2026-05-23 12:00:01] === setup_dev_env.sh finished successfully ===
[2026-05-23 12:00:01] Log file: /var/log/setup_dev_env.log
```

---

## Проверка результата

```bash
# убедиться, что пользователи в группе dev
getent group dev

# проверить sudoers-файл
sudo visudo -cf /etc/sudoers.d/dev_nopasswd

# посмотреть права директорий
ls -la /home/workdirs/

# посмотреть ACL
getfacl /home/workdirs/alice_workdir

# посмотреть лог
cat /var/log/setup_dev_env.log
```

---

## Требования

- Linux (тестировалось на Ubuntu 22.04 / Debian 12)
- Bash ≥ 4.0
- Пакет `acl` (`apt install acl`)
- Права root / sudo

---

## Структура репозитория

```
.
├── setup_dev_env.sh   # основной скрипт
└── README.md          # документация
```
