Backup tools performance test
=============================

Script used for testing the performance and system resources usage of six remote incremental backup tools: Rsync, Rdiff-backup, obnam, hashbackup, and attic, and borg.

The tests are performed in three distinct remote backup operations: full backup, incremental backup and data restoration. Additionally they are performed with three configurations: without compression and encryption, only with compression and with both activated.

This script was produced as part of the paper "**Open Source Tools for Remote Incremental Backups on Linux: An Experimental Evaluation**" available here: http://www.si-journal.org/index.php/JSI/article/view/205
It has been modified in this fork to test a different set of tools that have similar functionality as the tools originally tested.
Additionally, the original test was designed to be performed from one server to another. This test has been modified to run on one server, but is designed to be performed from one drive to another. It could easily be configured to be remote again.

## Usage

```
$ ./backup_tools_test.sh      # Execute all tests
$ ./backup_tools_test.sh N    # Execute only a specific test
```

## Requirements

Client: ssh, openssl, dstat, rsync, rdiff-backup, rsyncrypto, gnupg, obnam, hashbackup, attic, borg

## Tests configuration

  #  | tool          | compression | encryption
:---:| ------------- |:-----------:|:----------:
  0  | rsync         |             |
  1  | rsync         |   **x**     |
  2  | rdiff-backup  |             |
  3  | rdiff-backup  |   **x**     |
  4  | rdiff-backup  |   **x**     |  **x**
  5  | obnam         |             |
  6  | obnam         |   **x**     |
  7  | obnam         |   **x**     |  **x**
  8  | hashbackup    |   **x**     |  **x**
  9  | attic         |   **x**     |
  10 | attic         |   **x**     |  **x**
  11 | borg          |   **x**     |
  12 | borg          |   **x**     |  **x**

Test groups: [0,2,5],[1,3,6,9,11],[4,7,8,10,12]

## License

Licensed under the MIT license.