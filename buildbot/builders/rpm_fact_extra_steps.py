#############################
# DO NOT REMOVE 
# unless MDEV-9584 is closed as "won't fix".
#
# MDEV-9584, MDEV-9766 - Relaxed rules for yum upgrade
# The file implements additional steps for yum-based builders
# which can only be enabled on branches containing fixes 
# for MDEV-9584 and related bugs (still stalled/open, as of 2017-11-11).
# There are numerous steps, so probably they shouldn't be enabled
# on all branches
#####

# Upgrade From 10.1

    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 10.1 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    # Not Fedora because Fedora wants additional options, see below
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.1 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    # Fedora wants additional options, otherwise refuses to install
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.1 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            extra_opts="--best --allowerasing",
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 10.1 (all packages)",
            old_packages="MariaDB-*",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    # Not Fedora because Fedora wants additional options, see below
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.1 (all packages)",
            old_packages="MariaDB-*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    # Fedora wants additional options, otherwise refuses to install
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.1 (all packages)",
            old_packages="MariaDB-*",
            new_packages="MariaDB-*",
            extra_opts="--best --allowerasing",
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )

# Upgrade From 10.0

    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 10.0 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    # Not Fedora because Fedora wants additional options, see below
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    # Fedora wants additional options, otherwise refuses to install
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            extra_opts="--best --allowerasing",
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 10.0 (all packages)",
            old_packages="MariaDB-* -x MariaDB-Galera*",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    # Not Fedora because Fedora wants additional options, see below
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 (all packages)",
            old_packages="MariaDB-* -x MariaDB-Galera*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    # Fedora wants additional options, otherwise refuses to install
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 (all packages)",
            old_packages="MariaDB-* -x MariaDB-Galera*",
            new_packages="MariaDB-*",
            extra_opts="--best --allowerasing",
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )

# Upgrade From 10.0 Galera
    # manual_restart is added everywhere due to MDEV-9797

    # On CentOS 7 manual restart does not help, see MDEV-9797 (comments)
    # On Fedora, upgrade does not work, see MDEV-9807
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 10.0 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=rpm_test_branch
        )
    )
    # Not Fedora because Fedora wants additional options, see below
    # On CentOS 7 manual restart does not help, MDEV-9797 (comments)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    # Fedora wants additional options, otherwise refuses to install
    # Manual restart does not work, MDEV-9797 (comments)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            extra_opts="--best --allowerasing",
            manual_restart=1,
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )

# Upgrade From 5.5
    # Not Fedora because we don't build 5.5 for Fedora

    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 5.5 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 5.5 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 5.5 (all packages)",
            old_packages="MariaDB-* -x MariaDB-Galera*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 5.5 (all packages)",
            old_packages="MariaDB-* -x MariaDB-Galera*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )

# Upgrade From 5.5 Galera
    # Not Fedora because we don't build 5.5 for Fedora
    # Manual restart is added everywhere due to MDEV-9797

    # On CentOS 7 manual restart does not help, MDEV-9797 (comments)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MariaDB 5.5 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )
    # On CentOS 7 manual restart does not help, MDEV-9797 (comments)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 5.5 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=(lambda(step): dist_name != "fedora" and rpm_test_branch(step))
        )
    )

# Upgrade from MySQL 5.7
    # It's not installable on CentOS 6 (ERROR with rpm_check_debug vs depsolve).
    # Possibly it's the same for RHEL 6, we don't have it in buildbot.
    # So, we'll disable the tests for CentOS/RHEL 6.

    # This step does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MySQL 5.7",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (not (dist_name == "centos" and int(dist_num) == 6)) and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9798
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.7 (server, client)",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (not (dist_name == "centos" and int(dist_num) == 6)) and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9798 and MDEV-9799
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.7 (all packages)",
            old_packages="mysql-community-*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (not (dist_name == "centos" and int(dist_num) == 6)) and rpm_test_branch(step))
        )
    )

# Upgrade from MySQL 5.6
    # It's not installable on CentOS 6 (ERROR with rpm_check_debug vs depsolve).
    # Possibly it's the same for RHEL 6, we don't have it in buildbot.
    # So, we'll disable the tests for CentOS 6.

    # This step does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MySQL 5.6",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (not (dist_name == "centos" and int(dist_num) == 6)) and rpm_test_branch(step))
       )
    )
    # The step fails due to MDEV-9798
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.6 (server, client)",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (not (dist_name == "centos" and int(dist_num) == 6)) and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9798 and MDEV-9799
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.6 (all packages)",
            old_packages="mysql-community-*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (not (dist_name == "centos" and int(dist_num) == 6)) and rpm_test_branch(step))
        )
    )

# Upgrade from MySQL 5.5
    # MySQL 5.5 has packages for el 6,7 only (?)
    # But it's not installable on CentOS 6 (ERROR with rpm_check_debug vs depsolve).
    # Possibly it's the same for RHEL 6, we don't have it in buildbot.
    # So, we'll disable the tests for CentOS/RHEL 6.

    # This step does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="MySQL 5.5",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) >= 7 and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.5 (server, client)",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) >= 7 and rpm_test_branch(step))
        )
    )
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.5 (all packages)",
            old_packages="mysql-community-*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) >= 7 and rpm_test_branch(step))
        )
    )

# Upgrade from Percona 5.7
    # Percona 5.7 only has packages for el 6, 7

    # This step does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="Percona 5.7",
            old_packages="Percona-Server-server-57 Percona-Server-client-57",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) >= 6 and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9800
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="Percona 5.7 (server, client)",
            old_packages="Percona-Server-server-57 Percona-Server-client-57",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) >= 6 and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9800
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="Percona 5.7 (all packages)",
            old_packages="Percona-Server-*-57",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) >= 6 and rpm_test_branch(step))
        )
    )

# Upgrade from Percona 5.6
    # Percona 5.6 only has packages for el 5, 6, 7

    # This step does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="Percona 5.6",
            old_packages="Percona-Server-server-56 Percona-Server-client-56",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9800
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="Percona 5.6 (server, client)",
            old_packages="Percona-Server-server-56 Percona-Server-client-56",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9800
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="Percona 5.6 (all packages)",
            old_packages="Percona-Server-*-56",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and rpm_test_branch(step))
        )
    )

# Upgrade from Percona 5.5
    # Percona 5.5 only has packages for el 5, 6, 7

    # This step does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="Percona 5.5",
            old_packages="Percona-Server-server-55 Percona-Server-client-55",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9800
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="Percona 5.5 (server, client)",
            old_packages="Percona-Server-server-55 Percona-Server-client-55",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9800
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="Percona 5.5 (all packages)",
            old_packages="Percona-Server-*-55",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and rpm_test_branch(step))
        )
    )

# Upgrades from packages provided by distributions

    # mysql-server and mysql: provided by RHEL 5 (probably 6 too), CentOS 5, CentOS 6
    # Install and upgrade suggest to use FORCE_UPGRADE

    # The step fails on CentOS 5 due to MDEV-9803
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="mysql-server",
            old_packages="mysql-server mysql",
            new_packages="MariaDB-server MariaDB-client",
            force_upgrade=1,
            manual_restart=1,
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) <= 6 and rpm_test_branch(step))
        )
    )
    # The step fails on CentOS 5 due to MDEV-9803
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql-server (server, client)",
            old_packages="mysql-server mysql",
            new_packages="MariaDB-server MariaDB-client",
            force_upgrade=1,
            manual_restart=1,
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) <= 6 and rpm_test_branch(step))
        )
    )
    # Step fails because of MDEV-9812
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql-server (all packages)",
            old_packages="mysql-server mysql mysql-bench mysql-devel mysql-test",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) <= 6 and rpm_test_branch(step))
        )
    )

    # mysql51-mysql-server and mysql51-mysql: provided by RHEL 5, CentOS 5

    # This test does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="mysql51-mysql-server",
            old_packages="mysql51-mysql-server mysql51-mysql",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) == 5 and rpm_test_branch(step))
        )
    )
    # Step fails due to MDEV-9815
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql51-mysql-server (server, client)",
            old_packages="mysql51-mysql-server mysql51-mysql",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) == 5 and rpm_test_branch(step))
        )
    )
    # Step fails due to MDEV-9815
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql51 (all packages)",
            old_packages="mysql51*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) == 5 and rpm_test_branch(step))
        )
    )

    # mysql55-mysql-server and mysql55-mysql: provided by RHEL 5, CentOS 5

    # This test does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="mysql55-mysql-server",
            old_packages="mysql55-mysql-server mysql55-mysql",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) == 5 and rpm_test_branch(step))
        )
    )
    # Step fails due to MDEV-9815
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql55-mysql-server (server, client)",
            old_packages="mysql55-mysql-server mysql55-mysql",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) == 5 and rpm_test_branch(step))
        )
    )
    # Step fails due to MDEV-9815
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql55 (all packages)",
            old_packages="mysql55*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): (dist_name == "centos" or dist_name == "rhel") and int(dist_num) == 5 and rpm_test_branch(step))
        )
    )

    # mariadb-server and mariadb: provided by CentOS 7, Fedora 22, Fedora 23

    # Manual restart is added due to MDEV-9805
    # The step fails due to MDEV-9805 (CentOS), MDEV-9808 (Fedora)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="mariadb-server",
            old_packages="mariadb-server mariadb",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            # On some reason >=7 did not work
            doStepIf=(lambda(step): ((dist_name == "centos" and int(dist_num) != 5 and int(dist_num) != 6) or dist_name == "fedora") and rpm_test_branch(step))
        )
    )
    # Manual restart is added due to MDEV-9805
    # The step fails due to MDEV-9805 (CentOS), MDEV-9809 (Fedora)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb-server (server, client)",
            old_packages="mariadb-server mariadb",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=(lambda(step): ((dist_name == "centos" and int(dist_num) != 5 and int(dist_num) != 6) or dist_name == "fedora") and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9806 (CentOS)
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb-server (all packages)",
            old_packages="mariadb* -x mariadb-galera*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): dist_name == "centos" and int(dist_num) != 5 and int(dist_num) != 6 and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9809 (Fedora), allowerasing does not help
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb-server (all packages)",
            old_packages="mariadb* -x mariadb-galera*",
            new_packages="MariaDB-*",
            extra_opts="--allowerasing",
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )

    # mariadb-galera-server and mariadb: provided by Fedora 22, Fedora 23

    # This test does not upgrade anything, since the packages don't match
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="upgrade",
            upgrade_from="mariadb-galera-server",
            old_packages="mariadb-galera-server mariadb",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )
    # Extra options are added because Fedora requests them
    rpm_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb-galera-server",
            old_packages="mariadb-galera-server mariadb",
            new_packages="MariaDB-server MariaDB-client",
            extra_opts="--allowerasing",
            # Step fails due to MDEV-9809, allowerasing does not help
            doStepIf=(lambda(step): dist_name == "fedora" and rpm_test_branch(step))
        )
    )
