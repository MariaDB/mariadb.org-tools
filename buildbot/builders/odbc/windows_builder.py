def bld_windows_connector_odbc(name, cmake_params, skip32bit):

  f_win_connector_odbc = BuildFactory()


  f_win_connector_odbc.addStep(ShellCommand(
        name = "remove_old_build",
        command=["dojob", "pwd && rm -rf" , 
        WithProperties("d:\\buildbot\\%(buildername)s\\build || true")],
        timeout = 4*3600,
        haltOnFailure = True
  ));

  f_win_connector_odbc.addStep(SetPropertyFromCommand(
        property="buildrootdir",
        command=["pwd"],
  ))
# f_win_connector_odbc.addStep(maybe_git_checkout)
  f_win_connector_odbc.addStep(ShellCommand(
        name= "git_checkout",
        command=["dojob", WithProperties("pwd && rm -rf src && git clone -b %(branch)s %(repository)s src && cd src && git reset --hard %(revision)s && dir")],
        timeout=7200,
        doStepIf=do_step_win
  ));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "git_conc_tag_checkout",
        command=["dojob", WithProperties("pwd && cd src && git submodule init && git submodule update && cd libmariadb && git fetch --all --tags --prune")],
        timeout=7200,
        doStepIf=do_step_win
  ));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "build_package_32",
        command=["dojob",
        #-DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/tr http://timestamp.digicert.com /td sha256 /fd sha256 /a\"
        WithProperties("pwd && rm -rf win32 && mkdir win32 && cd win32 && del CMakeCache.txt && cmake ../src -G \"Visual Studio 17 2022\" -A\"Win32\" -DCONC_WITH_MSI=OFF -DCONC_WITH_UNIT_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=SCHANNEL -DALL_PLUGINS_STATIC=ON && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
        ],
        doStepIf= not skip32bit,
        haltOnFailure = True
	));
# atm neglecting chance of race between 2 parallel builds - doesn't look like real. atm.
  f_win_connector_odbc.addStep(ShellCommand(
        name= "test_install_package_32",
        command=["dojob",
#WithProperties("pwd && cd win32/packaging/windows && for %%a in (mariadb-connector-odbc-*32*.msi) do (msiexec /i %%a INSTALLFOLDER='C:\\testing\\odbc\\driver\\%(branch)s\\32' /qn /norestart")
          WithProperties("pwd && ls win32\\RelWithDebInfo\\*.dll && md C:\\testing\\odbc\\driver\\%(branch)s\\32\\plugin && xcopy /y /f win32\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\32 && xcopy /y /f win32\\libmariadb\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\32\\plugin || xcopy /y /f win32\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\32 && xcopy /y /f win32\\libmariadb\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\32\\plugin || true")
        ],
        doStepIf= not skip32bit,
        haltOnFailure = False
	));

#mariadb -u %%TEST_UID%% -p%%TEST_PASSWORD%% -e "DROP SCHEMA IF EXISTS %%TEST_SCHEMA%%"
#mariadb -u %%TEST_UID%% -p%%TEST_PASSWORD%% -e "CREATE SCHEMA %%TEST_SCHEMA%%" || true
  f_win_connector_odbc.addStep(ShellCommand(
        name= "test_run_32",
        command=["dojob",
        WithProperties("""
SET TEST_DSN=%(branch)s
SET TEST_DRIVER=%(branch)s
SET TEST_PORT=3306
SET TEST_SCHEMA=odbc%(branch)s
cd win32/test
ctest --output-on-failure""")
        ],
        doStepIf= not skip32bit,
        haltOnFailure = True
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "test_uninstall_package_32",
        command=["dojob",
#WithProperties("pwd && cd win32/packaging/windows && for %%a in (mariadb-connector-odbc-*32*.msi) do  (msiexec /uninstall %%a /qn /norestart")
        WithProperties("rm C:\\testing\\odbc\\driver\\%(branch)s\\32\\*.dll && rm C:\\testing\\odbc\\driver\\%(branch)s\\32\\plugin\\*.dll || true")
        ],
        doStepIf= not skip32bit,
        haltOnFailure = False
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "build_package_64",
        command=["dojob",
        #-DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/tr http://timestamp.digicert.com /td sha256 /fd sha256 /a\"
        WithProperties("rm -rf win64 && mkdir win64 && cd win64 && cmake ../src -G \"Visual Studio 17 2022\" -DCONC_WITH_MSI=OFF -DCONC_WITH_UNIT_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DINSTALL_PLUGINDIR=plugin -DALL_PLUGINS_STATIC=ON " + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
          ],
        haltOnFailure = True
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "create_publish_dir",
        command=["dojob",
        WithProperties("mkdir c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s || exit 0")]
        ))

  f_win_connector_odbc.addStep(ShellCommand(
        command=["dojob",
        WithProperties("cd win32 && xcopy /y /f packaging\\windows\\*.msi c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s")],
        doStepIf= not skip32bit
  ))
  f_win_connector_odbc.addStep(ShellCommand(
        command=["dojob",
        WithProperties("cd win64 && xcopy /y /f packaging\\windows\\*.msi c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s &&  md5sums c:/build_archive/%(buildername)s/%(branch)s/%(revision)s")]
  ))

### Copying also to the location where buildbot will really look for file to upload, and them rm -rf it
  f_win_connector_odbc.addStep(ShellCommand(
        name= "create_upload_dir",
        command=["dojob",
        WithProperties("if not exist \"C:\\buildbot\\win-connector_odbc\\build\\%(revision)s\" mkdir C:\\buildbot\\win-connector_odbc\\build\\%(revision)s && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* C:\\buildbot\\win-connector_odbc\\build\\%(revision)s")]
  ))

  f_win_connector_odbc.addStep(ShellCommand(
        name= "create_tmp_upload_dir",
        command=["dojob",
        WithProperties("if not exist \"C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s\" mkdir \"C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s\" && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s")]
  ))

  addPackageUploadStepWin(f_win_connector_odbc, 'win')

  f_win_connector_odbc.addStep(ShellCommand(
        name= "rm_tmp__upload_dir",
        command=["dojob",
        WithProperties("rm -rf \"C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s\"")]
  ))

  f_win_connector_odbc.addStep(ShellCommand(
        name= "benchmark_64",
        command=["dojob",
#WithProperties("pwd && cd win32/packaging/windows && for %%a in (mariadb-connector-odbc-*32*.msi) do (msiexec /i %%a INSTALLFOLDER='C:\\testing\\odbc\\driver\\%(branch)s\\32' /qn /norestart")
          WithProperties("pwd && ls win64\\RelWithDebInfo\\*.dll && md C:\\testing\\odbc\\driver\\%(branch)s\\64\\plugin && xcopy /y /f win64\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\64 && xcopy /y /f win64\\libmariadb\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\64\\plugin || xcopy /y /f win64\\RelWithDebInfo\\*.dll C:\\testing\\odbc\\driver\\%(branch)s\\64 && C:\\work\\benchmark\\x64\\Release\\benchmark -l ConnCpp1.1")
        ],
        haltOnFailure = False
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "clean_after_benchmark_64",
        command=["dojob",
#WithProperties("pwd && cd win32/packaging/windows && for %%a in (mariadb-connector-odbc-*32*.msi) do  (msiexec /uninstall %%a /qn /norestart")
        WithProperties("rm C:\\testing\\odbc\\driver\\%(branch)s\\64\\*.dll && rm C:\\testing\\odbc\\driver\\%(branch)s\\64\\plugin\\*.dll || true")
        ],
        haltOnFailure = False
	));

  return { 'name': name,
#        'slavename': "bb-win32",
        'slavename': "win-connectors",
        'builddir': name,
        'factory': f_win_connector_odbc,
        'category': "connectors" }

#bld_win_connector_odbc = bld_windows_connector_odbc("win_connector_odbc", "connector_c_2.3", " -DWITH_OPENSSL=OFF ", "v_2.3.7", False)
bld_codbc_windows= bld_windows_connector_odbc("codbc-windows", " -DWITH_SSL=SCHANNEL  -DINSTALL_PLUGINDIR=plugin", False)
bld_codbc_windows_gnutls= bld_windows_connector_odbc("codbc-windows-gnutls", " -DWITH_SSL=GNUTLS -DGNUTLS_LIBRARY=c:\\gnutls\\lib64\\libgnutls.dll.a -DGNUTLS_INCLUDE_DIR=c:\\gnutls\\include ", True)
