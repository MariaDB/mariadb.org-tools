Testing of MDEV-19210


Start:

$ docker-compose up

Now we have 3 containers, none with MariaDB running.

$ docker-compose exec node1 galera_new_cluster

$ docker-compose exec node1 ps -ef
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 06:22 ?        00:00:00 /sbin/init
root          12       1  0 06:22 ?        00:00:00 /usr/lib/systemd/systemd-journald
dbus          19       1  0 06:22 ?        00:00:00 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
mysql         66       1  1 06:23 ?        00:00:00 /usr/sbin/mariadbd --wsrep-new-cluster --wsrep_start_position=00000000-0000-0000-0000-000000000000:-1
root          92       0  0 06:23 pts/0    00:00:00 ps -ef


$ docker-compose exec node1 systemctl status mariadb.service
● mariadb.service - MariaDB 11.4.0 database server
   Loaded: loaded (/usr/lib/systemd/system/mariadb.service; disabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/mariadb.service.d
           └─migrated-from-my.cnf-settings.conf
   Active: active (running) since Thu 2023-11-23 06:23:04 UTC; 47s ago
     Docs: man:mariadbd(8)
           https://mariadb.com/kb/en/library/systemd/
  Process: 90 ExecStartPost=/bin/rm -f /var/lib/mysql/wsrep-start-position (code=exited, status=0/SUCCESS)
  Process: 25 ExecStartPre=/bin/sh -c [ ! -e /usr/bin/galera_recovery ] && VAR= ||   VAR=`cd /usr/bin/..; /usr/bin/galera_recovery`; [ $? -eq 0 ]   && echo _WSREP_START_POSITION=$VAR > /var/lib/mysql/wsrep-start-position || exit 1 (code=exited, status=0/SUCCESS)
 Main PID: 66 (mariadbd)
   Status: "Taking your SQL requests now..."
    Tasks: 24 (limit: 1638)
   Memory: 89.4M
   CGroup: /system.slice/mariadb.service
           └─66 /usr/sbin/mariadbd --wsrep-new-cluster --wsrep_start_position=00000000-0000-0000-0000-000000000000:-1

Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 0 [Note] /usr/sbin/mariadbd: ready for connections.
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: Version: '11.4.0-MariaDB'  socket: '/var/lib/mysql/mysql.sock'  port: 3306  MariaDB Server
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: Lowest cert index boundary for CC from group: 1
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: Min available from gcache for CC from group: 1
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: Server d56f67084c71 synced with group
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: Server status change joined -> synced
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: Synchronized with group, ready for connections
Nov 23 06:23:04 d56f67084c71 mariadbd[66]: 2023-11-23  6:23:04 1 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
Nov 23 06:23:04 d56f67084c71 systemd[1]: Started MariaDB 11.4.0 database server.


$ docker-compose exec node1 journalctl -f -u mariadb.service
...


new term: observer joining

$ docker-compose exec node2 systemctl start mariadb.service 

$ docker-compose exec node2 journalctl -f -u mariadb.service
-- Logs begin at Thu 2023-11-23 06:22:21 UTC. --
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 0 [Note] WSREP: Shifting JOINER -> JOINED (TO: 2)
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 0 [Note] WSREP: Processing event queue:... -nan% (0/0 events) complete.
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 0 [Note] WSREP: Member 0.0 (4799b0f5056f) synced with group.
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 0 [Note] WSREP: Processing event queue:...100.0% (1/1 events) complete.
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 0 [Note] WSREP: Shifting JOINED -> SYNCED (TO: 2)
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 2 [Note] WSREP: Server 4799b0f5056f synced with group
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 2 [Note] WSREP: Server status change joined -> synced
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 2 [Note] WSREP: Synchronized with group, ready for connections
Nov 23 06:27:08 4799b0f5056f mariadbd[70]: 2023-11-23  6:27:08 2 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
Nov 23 06:27:08 4799b0f5056f systemd[1]: Started MariaDB 11.4.0 database server.

$ docker-compose exec node3 systemctl start mariadb.service


$ docker exec -ti mdev-19210_node3_1 mariadb 


MariaDB [(none)]> show global status like 'wsrep_local_state%';
+---------------------------+--------------------------------------+
| Variable_name             | Value                                |
+---------------------------+--------------------------------------+
| wsrep_local_state_uuid    | c27926f6-89c8-11ee-bb0c-4ba8138cb725 |
| wsrep_local_state         | 4                                    |
| wsrep_local_state_comment | Synced                               |
+---------------------------+--------------------------------------+
3 rows in set (0.001 sec)



MariaDB [(none)]> use test;
Database changed
MariaDB [test]> create table t (i int primary key not null); 
Query OK, 0 rows affected (0.020 sec)

MariaDB [test]> insert into t select seq from seq_1_to_1000000;
Query OK, 1000000 rows affected (2.443 sec)
Records: 1000000  Duplicates: 0  Warnings: 0


$  docker-compose exec node2 systemctl stop  mariadb.service

more data:

MariaDB [test]> create table t2 like t; 
Query OK, 0 rows affected (0.020 sec)

MariaDB [test]> insert into t2 select seq from seq_1_to_10000000;
Query OK, 10000000 rows affected (29.217 sec)
Records: 10000000  Duplicates: 0  Warnings: 0


watch node2:

$ docker-compose exec node2 journalctl -f -u mariadb.service
-- Logs begin at Thu 2023-11-23 06:22:21 UTC. --
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: FTS optimize thread exiting.
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: Starting shutdown...
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: Restricted to 2016 pages due to innodb_buf_pool_dump_pct=25
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: Buffer pool(s) dump completed at 231123  6:33:16
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] InnoDB: Shutdown completed; log sequence number 70064612; transaction id 49
Nov 23 06:33:16 4799b0f5056f mariadbd[70]: 2023-11-23  6:33:16 0 [Note] /usr/sbin/mariadbd: Shutdown complete
Nov 23 06:33:16 4799b0f5056f systemd[1]: mariadb.service: Succeeded.
Nov 23 06:33:16 4799b0f5056f systemd[1]: Stopped MariaDB 11.4.0 database server.


start node2's mariadb:

$  docker-compose exec node2 systemctl start  mariadb.service


Nov 23 06:33:16 4799b0f5056f systemd[1]: mariadb.service: Succeeded.
Nov 23 06:33:16 4799b0f5056f systemd[1]: Stopped MariaDB 11.4.0 database server.
Nov 23 06:35:56 4799b0f5056f systemd[1]: Starting MariaDB 11.4.0 database server...
Nov 23 06:35:56 4799b0f5056f sh[513]: WSREP: Recovered position c27926f6-89c8-11ee-bb0c-4ba8138cb725:5
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] Starting MariaDB 11.4.0-MariaDB source revision 48486dc386a4a24b75ceec196b745d5b2792fefc as process 551
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: Loading provider /usr/lib64/galera-4/libgalera_smm.so initial position: c27926f6-89c8-11ee-bb0c-4ba8138cb725:5
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: wsrep_load(): loading provider library '/usr/lib64/galera-4/libgalera_smm.so'
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: wsrep_load(): Galera 26.4.16(re0529a83) by Codership Oy <info@codership.com> loaded successfully.
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: Initializing allowlist service v1
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: Initializing event service v1
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: CRC-32C: using 64-bit x86 acceleration.
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: Found saved state: c27926f6-89c8-11ee-bb0c-4ba8138cb725:5, safe_to_bootstrap: 0
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: 2023-11-23  6:35:56 0 [Note] WSREP: GCache DEBUG: opened preamble:
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: Version: 2
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: UUID: c27926f6-89c8-11ee-bb0c-4ba8138cb725
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: Seqno: 2 - 5
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: Offset: 1280
Nov 23 06:35:56 4799b0f5056f mariadbd[551]: Synced: 1

...

Nov 23 06:36:18 4799b0f5056f mariadbd[551]: View:
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   id: c27926f6-89c8-11ee-bb0c-4ba8138cb725:10
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   status: primary
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   protocol_version: 4
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   capabilities: MULTI-MASTER, CERTIFICATION, PARALLEL_APPLYING, REPLAY, ISOLATION, PAUSE, CAUSAL_READ, INCREMENTAL_WS, UNORDERED, PREORDERED, STREAMING, NBO
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   final: no
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   own_index: 1
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:   members(3):
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:         0: 7a9a0d71-89c9-11ee-831f-12830bd915d3, 7ade7401b374
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:         1: 8ec6b9fc-89ca-11ee-bc53-671c7bb1037c, 4799b0f5056f
Nov 23 06:36:18 4799b0f5056f mariadbd[551]:         2: c278cd7a-89c8-11ee-984e-f7ca9e0dea0e, d56f67084c71
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: =================================================
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Server status change initialized -> joined
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Draining apply monitors after IST up to 10
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: IST received: c27926f6-89c8-11ee-bb0c-4ba8138cb725:10
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Lowest cert index boundary for CC from sst: 5
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Min available from gcache for CC from sst: 5
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 0 [Note] WSREP: 1.0 (4799b0f5056f): State transfer from 0.0 (7ade7401b374) complete.
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 0 [Note] WSREP: Shifting JOINER -> JOINED (TO: 10)
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 0 [Note] WSREP: Processing event queue:... -nan% (0/0 events) complete.
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 0 [Note] WSREP: Member 1.0 (4799b0f5056f) synced with group.
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 0 [Note] WSREP: Processing event queue:...100.0% (1/1 events) complete.
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 0 [Note] WSREP: Shifting JOINED -> SYNCED (TO: 10)
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Server 4799b0f5056f synced with group
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Server status change joined -> synced
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: Synchronized with group, ready for connections
Nov 23 06:36:18 4799b0f5056f mariadbd[551]: 2023-11-23  6:36:18 2 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.


