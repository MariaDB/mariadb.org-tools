def bld_windows_connector_cpp(name, conc_branch, cmake_params, tag, skip32bit):

  f_win_connector_cpp = BuildFactory()


  f_win_connector_cpp.addStep(ShellCommand(
        name = "remove_old_build",
        command=["dojob", "pwd && rm -rf" , 
        WithProperties("d:\\buildbot\\%(buildername)s\\build")],
        timeout = 4*3600,
        haltOnFailure = True
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
        WithProperties("pwd && rm -rf win32 && mkdir win32 && cd win32 && del CMakeCache.txt && cmake ../src -G \"Visual Studio 15 2017\" -DCONC_WITH_MSI=OFF -DCONC_WITH_UNIT_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/a\" -DWITH_SSL=SCHANNEL && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
#WithProperties("pwd && rm -rf win32 && mkdir win32 && cd win32 && del CMakeCache.txt && cmake ../src -G \"Visual Studio 14 2015\" -DCONC_WITH_MSI=OFF -DCONC_WITH_UNIT_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/t http://timestamp.verisign.com/scripts/timstamp.dll -f c:\certs\Mariadb_code_signing_2019.pfx -p Pass1worD!!\" " + cmake_params + " && cmake --build . --config RelWithDebInfo")
#        WithProperties("cd win32 && del CMakeCache.txt && cmake ..\\src -G \"Visual Studio 14 2015\" -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build . --clean-first --config RelWithDebInfo --target package")
        ],
        doStepIf= not skip32bit,
        haltOnFailure = True
	));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "build_package_64",
        command=["dojob",
#        WithProperties("cd .. && rm -rf win64 && mkdir win64 && cd win64 && cmake ../build -G \"Visual Studio 10 Win64\" -DWIX_DIR=C:\georg\wix38\ && cmake --build . --config RelWithDebInfo")
        WithProperties("rm -rf win64 && mkdir win64 && cd win64 && cmake ../src -G \"Visual Studio 15 2017 Win64\" -DCONC_WITH_MSI=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SIGNCODE=1 -DSIGN_OPTIONS=\"/a\" -DINSTALL_PLUGINDIR=plugin" + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
          ],
        haltOnFailure = True
	));
#### Commenting signing steps, as signing is done as build process now(due do wthese steps do not work atm)
#  f_win_connector_cpp.addStep(ShellCommand(
#        name= "sign_packages32",
#        command=["dojob",
#        WithProperties("cd win32 && \"C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\Bin\\signtool\" sign /a /t http://timestamp.verisign.com/scripts/timstamp.dll wininstall\\*.msi")]
#  ))

#  f_win_connector_cpp.addStep(ShellCommand(
#        name= "sign_packages64",
#        command=["dojob",
#        WithProperties("cd win64 && \"C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\Bin\\signtool\" sign /a /t http://timestamp.verisign.com/scripts/timstamp.dll wininstall\\*.msi")]
#  ))

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
        WithProperties("if not exist \"d:\\buildbot\\win-connector_cpp\\build\\%(revision)s\" mkdir d:\\buildbot\\win-connector_cpp\\build\\%(revision)s && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* d:\\buildbot\\win-connector_cpp\\build\\%(revision)s")]
  ))

  f_win_connector_cpp.addStep(ShellCommand(
        name= "create_tmp_upload_dir",
        command=["dojob",
        WithProperties("if not exist \"C:\\bb\\%(buildername)s\\build\\%(revision)s\" mkdir \"C:\\bb\\%(buildername)s\\build\\%(revision)s\" && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* C:\\bb\\%(buildername)s\\build\\%(revision)s")]
  ))

  addPackageUploadStepWin(f_win_connector_cpp, 'win')

  f_win_connector_cpp.addStep(ShellCommand(
        name= "build_package_64_debug",
        command=["dojob",
        WithProperties("rm -rf win64d && mkdir win64d && cd win64d && cmake ../src -G \"Visual Studio 15 2017 Win64\" -DCONC_WITH_MSI=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SIGNCODE=0 -DINSTALL_PLUGINDIR=plugin" + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config Debug")
          ],
        haltOnFailure = True
	));

  f_win_connector_cpp.addStep(ShellCommand(
        name= "test_with_built_release",
        command=["dojob",
        WithProperties("cd win64d\\test && ls -l mariadbcpp.dll && copy ..\\..\\win64\\RelWithDebInfo\\mariadbcpp.dll .\\ && ls -l mariadbcpp.dll && ctest --VV")
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

bld_win_connector_cpp = bld_windows_connector_cpp("ccpp-windows", "3.1", " -DWITH_SSL=SCHANNEL  -DINSTALL_PLUGINDIR=plugin", "v3.1.7", True)
