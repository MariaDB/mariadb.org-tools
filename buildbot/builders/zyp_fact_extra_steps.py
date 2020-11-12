#############################
# DO NOT REMOVE 
# unless MDEV-9584 is closed as "won't fix".
#
# MDEV-9584, MDEV-9766 - Relaxed rules for yum upgrade
# The file implements additional steps for zyp-based builders
# which can only be enabled on branches containing fixes 
# for MDEV-9584 and related bugs (still stalled/open, as of 2017-11-11).
# There are numerous steps, so probably they shouldn't be enabled
# on all branches
#####

# Upgrade from MariaDB 10.1

    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 10.1 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.1 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 10.1 (all packages)",
            old_packages="MariaDB-*",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.1 (all packages)",
            old_packages="MariaDB-*",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="dist-upgrade",
            upgrade_from="MariaDB 10.1",
            old_packages="MariaDB-*",
            new_packages="",
            doStepIf=rpm_test_branch
        )
    )

# Upgrade from MariaDB 10.0

    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 10.0 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 10.0 (all packages)",
            old_packages="MariaDB-client MariaDB-common MariaDB-devel MariaDB-server MariaDB-shared MariaDB-test MariaDB-*-engine",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    # This step fails on opensuse 13 x86_64 and SLES11 x86)64 due to MDEV-9850
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 (all packages)",
            old_packages="MariaDB-client MariaDB-common MariaDB-devel MariaDB-server MariaDB-shared MariaDB-test MariaDB-*-engine",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="dist-upgrade",
            upgrade_from="MariaDB 10.0",
            old_packages="MariaDB-client MariaDB-common MariaDB-devel MariaDB-server MariaDB-shared MariaDB-test MariaDB-*-engine",
            new_packages="",
            doStepIf=rpm_test_branch
        )
    )

# Upgrade from Galera 10.0

    # This step doesn't work due to MDEV-9807
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 10.0 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    # Restart is needed because of MDEV-9797
    # On openSUSE 13 manual restart does not work
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 10.0 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=rpm_test_branch
        )
    )
    # Restart is needed because of MDEV-9797
    # On openSUSE 13 manual restart does not work
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="dist-upgrade",
            upgrade_from="MariaDB 10.0 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="",
            manual_restart=1,
            doStepIf=rpm_test_branch
        )
    )

# Upgrade from MariaDB 5.5

    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 5.5 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 5.5 (server, client)",
            old_packages="MariaDB-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 5.5 (all packages)",
            old_packages="MariaDB-client MariaDB-common MariaDB-devel MariaDB-server MariaDB-shared MariaDB-test",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 5.5 (all packages)",
            old_packages="MariaDB-client MariaDB-common MariaDB-devel MariaDB-server MariaDB-shared MariaDB-test",
            new_packages="MariaDB-*",
            doStepIf=rpm_test_branch
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="dist-upgrade",
            upgrade_from="MariaDB 5.5",
            old_packages="MariaDB-client MariaDB-common MariaDB-devel MariaDB-server MariaDB-shared MariaDB-test",
            new_packages="",
            doStepIf=rpm_test_branch
        )
    )

# Upgrade from Galera 5.5

    # This step does not work because of MDEV-9807
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MariaDB 5.5 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=rpm_test_branch
        )
    )
    # Restart is needed because of MDEV-9797
    # On openSUSE 13 manual restart does not work
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MariaDB 5.5 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=rpm_test_branch
        )
    )
    # Restart is needed because of MDEV-9797
    # On openSUSE 13 manual restart does not work
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="dist-upgrade",
            upgrade_from="MariaDB 5.5 Galera",
            old_packages="MariaDB-Galera-server MariaDB-client",
            new_packages="",
            manual_restart=1,
            doStepIf=rpm_test_branch
        )
    )

# Upgrade from MySQL 5.7
    # MySQL 5.7 has packages for sles 12 x86_64

    # This test does not upgrade anything, since the packages don't match
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MySQL 5.7",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): int(dist_num) == 12 and arch == "x86_64" and rpm_test_branch(step))
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.7 (server, client)",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): int(dist_num) == 12 and arch == "x86_64" and rpm_test_branch(step))
        )
    )
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.7 (all packages)",
            old_packages="mysql-community-*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) == 12 and arch == "x86_64" and rpm_test_branch(step))
        )
    )

# Upgrade from MySQL 5.6
    # MySQL 5.6 has packages for sles 11, 12 x86)64

    # This test does not upgrade anything, since the packages don't match
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MySQL 5.6",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): int(dist_num) < 13 and arch == "x86_64" and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9798
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.6 (server, client)",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): int(dist_num) < 13 and arch == "x86_64" and rpm_test_branch(step))
        )
    )

    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.6 (all packages)",
            old_packages="mysql-community-bench mysql-community-client mysql-community-common mysql-community-devel mysql-community-embedded mysql-community-embedded-devel mysql-community-libs mysql-community-server mysql-community-test",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) < 13 and arch == "x86_64" and rpm_test_branch(step))
        )
    )

# Upgrade from MySQL 5.5
    # MySQL 5.5 has packages for sles 11 x86_64

    # This step does not upgrade anything, since the packages don't match
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="MySQL 5.5",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): int(dist_num) == 11 and arch == "x86_64" and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9798
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.5 (server, client)",
            old_packages="mysql-community-server mysql-community-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): int(dist_num) == 11 and arch == "x86_64" and rpm_test_branch(step))
        )
    )
    # The step fails due to MDEV-9798
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="MySQL 5.5 (all packages)",
            old_packages="mysql-community-bench mysql-community-client mysql-community-common mysql-community-devel mysql-community-embedded mysql-community-embedded-devel mysql-community-libs mysql-community-server mysql-community-test",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) == 11 and arch == "x86_64" and rpm_test_branch(step))
        )
    )

# Upgrades from packages provided by distributions

    # mysql and mysql-client: provided by SLES 11

    # This test does not upgrade anything, since the packages don't match
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="mysql",
            old_packages="mysql mysql-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): int(dist_num) == 11 and rpm_test_branch(step))
        )
    )
    # Manual restart is added due to MDEV-9819
    # but it does not help
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql (server, client)",
            old_packages="mysql mysql-client",
            new_packages="MariaDB-server MariaDB-client",
            manual_restart=1,
            doStepIf=(lambda(step): int(dist_num) == 11 and rpm_test_branch(step))
        )
    )
    # Manual restart is added due to MDEV-9819
    # but it does not help
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql (all packages)",
            old_packages="mysql*",
            new_packages="MariaDB-*",
            manual_restart=1,
            doStepIf=(lambda(step): int(dist_num) == 11 and rpm_test_branch(step))
        )
    )

    # mariadb and mariadb-client: provided by SLES 12, 13

    # This test does not upgrade anything, since the packages don't match
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="mariadb",
            old_packages="mariadb mariadb-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
            # doStepIf=(lambda(step): int(dist_num) > 11 and rpm_test_branch(step))
        )
    )
    # This step fails due to MDEV-9796 (workaround does not help)
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb (server, client)",
            old_packages="mariadb mariadb-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): int(dist_num) > 11 and rpm_test_branch(step))
        )
    )
    # It's fine for SLES 12, but on openSUSE 13 there are server and server-debug versions,
    # which can't be installed together; so, we have to split the test, see below
    # This step fails due to MDEV-9796 (workaround does not help)
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb (all packages)",
            old_packages="mariadb*",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) == 12 and rpm_test_branch(step))
        )
    )
    # Variation for newer openSUSE where mariadb-debug-version also exists
    # This step fails due to MDEV-9796, workaround does not help
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb (all packages)",
            old_packages="mariadb mariadb-bench mariadb-client mariadb-errormessages mariadb-test mariadb-tools",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) > 12 and rpm_test_branch(step))
        )
    )
    # And the same for debug version
    # other packages require mariadb, so we are skipping them to see how it goes with the server only
    # This step fails due to MDEV-9796, workaround does not help
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mariadb-debug-version",
            old_packages="mariadb-debug-version",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) > 12 and rpm_test_branch(step))
        )
    )

    # mysql-community-server and mysql-community-client: provided by openSUSE 13

    # This test does not upgrade anything, since the packages don't match
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="update",
            upgrade_from="mysql-community-server",
            old_packages="mysql-community-server mysql-community-server-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=False
#            doStepIf=(lambda(step): int(dist_num) > 12 and rpm_test_branch(step))
        )
    )
    # This step does not work due to MDEV-9796 (workaround does not help)
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql-community-server (server, client)",
            old_packages="mysql-community-server mysql-community-server-client",
            new_packages="MariaDB-server MariaDB-client",
            doStepIf=(lambda(step): int(dist_num) > 12 and rpm_test_branch(step))
        )
    )
    # We need to exclude mysql-community-server-debug-version, and it seems there is no way to do it in zypper,
    # so we have to list all packages explicitly
    # This step does not work due to MDEV-9796 (workaround does not help)
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql-community-server (all packages)",
            old_packages="mysql-community-server mysql-community-server-bench mysql-community-server-client mysql-community-server-errormessages mysql-community-server-test mysql-community-server-tools",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) > 12 and rpm_test_branch(step))
        )
    )
    # And now while we are at it, do the debug-version as well
    # other packages require mysql-community-server, so we'll skip it to see how it goes with the server only
    # This step does not work due to MDEV-9796 (workaround does not help)
    zyp_fact.addStep(
         getRpmUpgradeStep(kvm_image, args, kvm_scpopt, port, distro, dist_name, dist_num, dist_arch,
            action="install",
            upgrade_from="mysql-community-server-debug-version",
            old_packages="mysql-community-server-debug-version",
            new_packages="MariaDB-*",
            doStepIf=(lambda(step): int(dist_num) > 12 and rpm_test_branch(step))
        )
    )
