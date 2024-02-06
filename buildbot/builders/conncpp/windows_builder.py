def bld_windows_connector_cpp(name, conc_branch, cmake_params, tag, skip32bit):

  f_win_connector_cpp = BuildFactory()


  f_win_connector_cpp.addStep(ShellCommand(
        name = "remove_old_build",
        command=["dojob", 
        WithProperties("pwd && ls && rm -rf c:\\buildbot\\build\\%(buildername)s\\build\\* && ls")],
        timeout = 4*3600,
        haltOnFailure = False
  ));

  f_win_connector_cpp.addStep(SetPropertyFromCommand(
        property="buildrootdir",
        command=["pwd"],
  ))
# f_win_connector_cpp.addStep(maybe_git_checkout)
  f_win_connector_cpp.addStep(ShellCommand(
        name= "git_checkout",
        command=["dojob", WithProperties("pwd && rm -rf src && git clone -b %(branch)s %(repository)s src && cd src && git reset --hard %(revision)s && dir")],
        timeout=7200,
        doStepIf=do_step_win
  ));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "git_conc_tag_checkout",
        command=["dojob", WithProperties("pwd && cd src && git submodule init && git submodule update && cd libmariadb && git fetch --all --tags --prune")],
        timeout=7200,
        doStepIf=do_step_win
  ));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "build_package_32",
        command=["dojob",
        # -DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/tr http://timestamp.digicert.com /td sha256 /fd sha256 /a\"
        WithProperties("pwd && rm -rf win32 && mkdir win32 && cd win32 && del CMakeCache.txt && cmake ../src -G \"Visual Studio 17 2022\" -A\"Win32\" -DCONC_WITH_MSI=OFF -DCONC_WITH_UNIT_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=SCHANNEL && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
        ],
        doStepIf= not skip32bit,
        haltOnFailure = True
	));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "build_package_64",
        command=["dojob",
        # -DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/tr http://timestamp.digicert.com /td sha256 /fd sha256 /a\"
        WithProperties("rm -rf win64 && mkdir win64 && cd win64 && cmake ../src -G \"Visual Studio 17 2022\" -A x64 -DCONC_WITH_MSI=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DINSTALL_PLUGINDIR=plugin -DCONC_WITH_UNIT_TESTS=OFF -DWITH_SSL=SCHANNEL" + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
          ],
        haltOnFailure = True
	));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "create_publish_dir",
        command=["dojob",
        WithProperties("mkdir c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s || exit 0")]
        ))

  f_win_connector_cpp.addStep(ShellCommand(
        name= "publish_win32",
        command=["dojob",
        WithProperties("cd win32  && xcopy /y /f wininstall\\*.msi c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s &&  md5sums c:/build_archive/%(buildername)s/%(branch)s/%(revision)s")],
        doStepIf= not skip32bit
  ))

  f_win_connector_cpp.addStep(ShellCommand(
        name= "publish_win64",
        command=["dojob",
        WithProperties("cd win64 && xcopy /y /f wininstall\\*.msi c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s &&  md5sums c:/build_archive/%(buildername)s/%(branch)s/%(revision)s")]
  ))

#f_win_connector_cpp.addStep(ShellCommand(
#        name= "create_upload_dir",
#        command=["dojob",
#        WithProperties("mkdir c:\\bzr\\bb-win32\\connector_cpp\\build\\%(revision)s && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* c:\\bzr\\bb-win32\\connector_cpp\\build\\%(revision)s")]
#        ))
### Copying also to the location where buildbot will really look for file to upload, and them rm -rf it
  f_win_connector_cpp.addStep(ShellCommand(
        name= "create_upload_dir",
        command=["dojob",
        WithProperties("if not exist \"c:\\buildbot\\win-connector_cpp\\build\\%(revision)s\" mkdir c:\\buildbot\\win-connector_cpp\\build\\%(revision)s && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* c:\\buildbot\\win-connector_cpp\\build\\%(revision)s")]
  ))

  f_win_connector_cpp.addStep(ShellCommand(
        name= "create_tmp_upload_dir",
        command=["dojob",
        WithProperties("if not exist \"C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s\" mkdir \"C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s\" && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* C:\\buildbot\\build\\%(buildername)s\\build\\%(revision)s")]
  ))

  addPackageUploadStepWin(f_win_connector_cpp, 'win')

  f_win_connector_cpp.addStep(ShellCommand(
        name= "build_package_64_debug",
        command=["dojob",
        # -DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/tr http://timestamp.digicert.com /td sha256 /fd sha256 /a\"
        WithProperties("rm -rf win64d && mkdir win64d && cd win64d && cmake ../src -G \"Visual Studio 17 2022\" -A x64 -DCONC_WITH_MSI=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DINSTALL_PLUGINDIR=plugin" + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config Debug")
          ],
        haltOnFailure = True
	));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "test_with_built_release",
        command=["dojob",
        WithProperties("cd win64d\\test && ls -l mariadbcpp.dll && copy ..\\..\\win64\\RelWithDebInfo\\mariadbcpp.dll .\\ && ls -l mariadbcpp.dll && ctest --output-on-failure")
          ],
        haltOnFailure = True
	));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "rm_tmp__upload_dir",
        command=["dojob",
        WithProperties("rm -rf \"C:\\bb\\%(buildername)s\\build\\%(revision)s\"")]
  ))

  return { 'name': name,
#        'slavename': "bb-win32",
        'slavename': "win-connectors",
        'builddir': name,
        'factory': f_win_connector_cpp,
        'category': "connectors" }

bld_win_connector_cpp = bld_windows_connector_cpp("ccpp-windows", "", "", "", True)
