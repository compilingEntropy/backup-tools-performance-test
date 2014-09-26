Backup tools performance test
=============================

Script used for testing the performance and system resources usage of five remote incremental backup tools: Rsync, Rdiff-backup, Duplicity, Areca and Link-Backup.

The tests are performed in three distinct remote backup operations: full backup, incremental backup and data restoration. Additionally they are performed with three configurations: without compression and encryption, only with compression and with both activated.

This script was produced as part of the paper "**Open Source Tools for Remote Incremental Backups on Linux: An Experimental Evaluation**" available here: http://www.si-journal.org/index.php/JSI/article/view/205

## Usage

```
$ ./backup_tools_test.sh      # Execute all tests
$ ./backup_tools_test.sh N    # Execute only a specific test
```

## Requirements

Client: ssh, dstat, rsync, rdiff-backup, duplicity, areca and link-backup
Server: sshd

## Tests configuration

  #  | tool          | compression | encryption
:---:| ------------- |:-----------:|:----------:
  0  | rsync         |             |
  1  | rdiff-backup  |             |
  2  | rdiff-backup  |   **x**     |
  3  | duplicity     |   **x**     |
  4  | duplicity     |   **x**     |  **x**
  5  | areca         |             |
  6  | areca         |   **x**     |
  7  | areca         |   **x**     |  **x**
  8  | link-backup   |             |

Test groups: [0,1,5,8], [2,3,6], [4,7]

## License

Licensed under the MIT license.