def bld_windows_connector_odbc(name, conc_branch, cmake_params):

  f_win_connector_odbc = factory.BuildFactory()


  f_win_connector_odbc.addStep(ShellCommand(
        name = "remove_old_build",
        command=["dojob", "pwd && rm -rf" , 
        WithProperties("d:\\buildbot\\%(buildername)s\\build")],
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
        name= "connc_git_checkout",
        command=["dojob", WithProperties("rm -rf connector_c && git clone -b " + conc_branch + " --depth 1 \"https://github.com/MariaDB/mariadb-connector-c.git\" connector_c")],
        timeout=7200,
	doStepIf=do_step_win
  ));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "build_connc_32",
        command=["dojob",
        WithProperties("pwd && cd connector_c && del CMakeCache.txt && cmake " + cmake_params + " . -G \"Visual Studio 14 2015\" && cmake --build . --config RelWithDebInfo")
#        WithProperties("cd win32 && del CMakeCache.txt && cmake ..\\src -G \"Visual Studio 14 2015\" -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build . --clean-first --config RelWithDebInfo --target package")
        ],
        haltOnFailure = True
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "build_package_32",
        command=["dojob",
        WithProperties("pwd && rm -rf win32 && mkdir win32 && cd win32 && del CMakeCache.txt && cmake ../src -G \"Visual Studio 14 2015\" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMARIADB_INCLUDE_DIR=%(buildrootdir)s/connector_c/include -DMARIADB_LIBRARY_DIR=%(buildrootdir)s/connector_c/libmariadb/RelWithDebInfo " + cmake_params + " && cmake --build . --config RelWithDebInfo")
#        WithProperties("cd win32 && del CMakeCache.txt && cmake ..\\src -G \"Visual Studio 14 2015\" -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build . --clean-first --config RelWithDebInfo --target package")
        ],
        haltOnFailure = True
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "build_connc_64",
        command=["dojob",
#        WithProperties("pwd && cd .. && rm -rf win32 && mkdir win32 && cd win32 && del CMakeCache.txt && cmake ../build -G \"Visual Studio 10\" -DWIX_DIR=C:\georg\wix38\ && cmake --build . --config RelWithDebInfo")
        WithProperties("pwd && cd connector_c && git clean -fxd && cmake . -G \"Visual Studio 14 2015 Win64\" " + cmake_params + " && cmake --build . --clean-first --config RelWithDebInfo && cd ..")
#        WithProperties("cd win32 && del CMakeCache.txt && cmake ..\\src -G \"Visual Studio 14 2015\" -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build . --clean-first --config RelWithDebInfo --target package")
        ],
        haltOnFailure = True
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "build_package_64",
        command=["dojob",
#        WithProperties("cd .. && rm -rf win64 && mkdir win64 && cd win64 && cmake ../build -G \"Visual Studio 10 Win64\" -DWIX_DIR=C:\georg\wix38\ && cmake --build . --config RelWithDebInfo")
        WithProperties("rm -rf win64 && mkdir win64 && cd win64 && cmake ../src -G \"Visual Studio 14 Win64\" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMARIADB_INCLUDE_DIR=%(buildrootdir)s/connector_c/include -DMARIADB_LIBRARY_DIR=%(buildrootdir)s/connector_c/libmariadb/RelWithDebInfo " + cmake_params + " && cmake --build . --config RelWithDebInfo")
          ],
        haltOnFailure = True
	));

  f_win_connector_odbc.addStep(ShellCommand(
        name= "sign_packages32",
        command=["dojob",
        WithProperties("cd win32 && \"C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\Bin\\signtool\" sign /a /t http://timestamp.verisign.com/scripts/timstamp.dll wininstall\\*.msi")]
  ))

  f_win_connector_odbc.addStep(ShellCommand(
        name= "sign_packages64",
        command=["dojob",
        WithProperties("cd win64 && \"C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\Bin\\signtool\" sign /a /t http://timestamp.verisign.com/scripts/timstamp.dll wininstall\\*.msi")]
  ))

  f_win_connector_odbc.addStep(ShellCommand(
        name= "create_publish_dir",
        command=["dojob",
        WithProperties("mkdir c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s || exit 0")]
        ))

  f_win_connector_odbc.addStep(ShellCommand(
        name= "publish_win32",
        command=["dojob",
        WithProperties("cd win32  && xcopy /y /f wininstall\\*.msi c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s &&  md5sums c:/build_archive/%(buildername)s/%(branch)s/%(revision)s")]
  ))

  f_win_connector_odbc.addStep(ShellCommand(
        name= "publish_win64",
        command=["dojob",
        WithProperties("cd win64 && xcopy /y /f wininstall\\*.msi c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s &&  md5sums c:/build_archive/%(buildername)s/%(branch)s/%(revision)s")]
  ))

#f_win_connector_odbc.addStep(ShellCommand(
#        name= "create_upload_dir",
#        command=["dojob",
#        WithProperties("mkdir c:\\bzr\\bb-win32\\connector_odbc\\build\\%(revision)s && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* c:\\bzr\\bb-win32\\connector_odbc\\build\\%(revision)s")]
#        ))
  f_win_connector_odbc.addStep(ShellCommand(
        name= "create_upload_dir",
        command=["dojob",
        WithProperties("if not exist \"d:\\buildbot\\win-connector_odbc\\build\\%(revision)s\" mkdir d:\\buildbot\\win-connector_odbc\\build\\%(revision)s && xcopy /y /f c:\\build_archive\\%(buildername)s\\%(branch)s\\%(revision)s\\* d:\\buildbot\\win-connector_odbc\\build\\%(revision)s")]
  ))

  addPackageUploadStepWin(f_win_connector_odbc, 'win')

  return { 'name': name,
#        'slavename': "bb-win32",
        'slavename': "win-connectors",
        'builddir': name,
        'factory': f_win_connector_odbc,
        'category': "connectors" }

bld_win_connector_odbc = bld_windows_connector_odbc("win_connector_odbc", "connector_c_2.3", " -DWITH_OPENSSL=OFF ")
bld_win_connector_odbc_new = bld_windows_connector_odbc("win_connector_odbc_new", "master", " -DWITH_SSL=SCHANNEL ")
