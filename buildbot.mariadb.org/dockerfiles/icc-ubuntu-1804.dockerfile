#
# Buildbot worker for building MariaDB
#
# Provides a base Ubuntu image with latest buildbot worker installed
# and MariaDB build dependencies

FROM      intel/oneapi-hpckit
LABEL maintainer="MariaDB Buildbot maintainers"

# This will make apt-get install without question
ARG DEBIAN_FRONTEND=noninteractive

# Enable apt sources
RUN sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list

# Install updates and required packages
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y build-dep -q mariadb-server && \
    apt-get -y install -q \
    apt-utils build-essential python-dev sudo git \
    devscripts equivs libcurl4-openssl-dev flex \
    ccache python3 python3-pip curl wget libssl-dev libzstd-dev \
    libevent-dev dpatch gawk gdb libboost-dev libcrack2-dev \
    libjudy-dev libnuma-dev libsnappy-dev libxml2-dev \
    unixodbc-dev uuid-dev fakeroot iputils-ping dh-exec libpcre2-dev \
    libarchive-dev libedit-dev liblz4-dev dh-systemd flex libboost-atomic-dev \
    libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev \
    libboost-regex-dev libboost-system-dev libboost-thread-dev

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# autobake-deb will need sudo rights
RUN usermod -a -G sudo buildbot
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Upgrade pip and install packages
RUN pip3 install -U pip virtualenv
RUN pip3 install buildbot-worker && \
    pip3 --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN apt-get -y install dumb-init

ENV ACL_BOARD_VENDOR_PATH='/opt/Intel/OpenCLFPGA/oneAPI/Boards'
ENV ADVISOR_2021_DIR='/opt/intel/oneapi/advisor/2021.4.0'
ENV APM='/opt/intel/oneapi/advisor/2021.4.0/perfmodels'
ENV CCL_CONFIGURATION='cpu_gpu_dpcpp'
ENV CCL_ROOT='/opt/intel/oneapi/ccl/2021.4.0'
ENV CLASSPATH='/opt/intel/oneapi/mpi/2021.4.0//lib/mpi.jar:/opt/intel/oneapi/dal/2021.4.0/lib/onedal.jar'
ENV CLCK_ROOT='/opt/intel/oneapi/clck/2021.4.0'
ENV CMAKE_PREFIX_PATH='/opt/intel/oneapi/vpl/2021.6.0:/opt/intel/oneapi/tbb/2021.4.0/env/..:/opt/intel/oneapi/dal/2021.4.0'
ENV CMPLR_ROOT='/opt/intel/oneapi/compiler/2021.4.0'
ENV CONDA_DEFAULT_ENV='intelpython-python3.7'
ENV CONDA_EXE='/opt/intel/oneapi/intelpython/latest/bin/conda'
ENV CONDA_PREFIX='/opt/intel/oneapi/intelpython/latest'
ENV CONDA_PROMPT_MODIFIER='(intelpython-python3.7) '
ENV CONDA_PYTHON_EXE='/opt/intel/oneapi/intelpython/latest/bin/python'
ENV CONDA_SHLVL='1'
ENV CPATH='/opt/intel/oneapi/vpl/2021.6.0/include:/opt/intel/oneapi/tbb/2021.4.0/env/../include:/opt/intel/oneapi/mpi/2021.4.0//include:/opt/intel/oneapi/mkl/2021.4.0/include:/opt/intel/oneapi/ippcp/2021.4.0/include:/opt/intel/oneapi/ipp/2021.4.0/include:/opt/intel/oneapi/dpl/2021.5.0/linux/include:/opt/intel/oneapi/dnnl/2021.4.0/cpu_dpcpp_gpu_dpcpp/lib:/opt/intel/oneapi/dev-utilities/2021.4.0/include:/opt/intel/oneapi/dal/2021.4.0/include:/opt/intel/oneapi/compiler/2021.4.0/linux/include:/opt/intel/oneapi/ccl/2021.4.0/include/cpu_gpu_dpcpp'
ENV CPLUS_INCLUDE_PATH='/opt/intel/oneapi/clck/2021.4.0/include'
ENV DAALROOT='/opt/intel/oneapi/dal/2021.4.0'
ENV DALROOT='/opt/intel/oneapi/dal/2021.4.0'
ENV DAL_MAJOR_BINARY='1'
ENV DAL_MINOR_BINARY='1'
ENV DNNLROOT='/opt/intel/oneapi/dnnl/2021.4.0/cpu_dpcpp_gpu_dpcpp'
ENV DPL_ROOT='/opt/intel/oneapi/dpl/2021.5.0'
ENV FI_PROVIDER_PATH='/opt/intel/oneapi/mpi/2021.4.0//libfabric/lib/prov:/usr/lib64/libfabric'
ENV FPGA_VARS_ARGS=''
ENV FPGA_VARS_DIR='/opt/intel/oneapi/compiler/2021.4.0/linux/lib/oclfpga'
ENV GDB_INFO='/opt/intel/oneapi/debugger/10.2.4/documentation/info/'
ENV INFOPATH='/opt/intel/oneapi/debugger/10.2.4/gdb/intel64/lib'
ENV INSPECTOR_2021_DIR='/opt/intel/oneapi/inspector/2021.4.0'
ENV INTELFPGAOCLSDKROOT='/opt/intel/oneapi/compiler/2021.4.0/linux/lib/oclfpga'
ENV INTEL_LICENSE_FILE='/opt/intel/licenses:/root/intel/licenses:/opt/intel/oneapi/clck/2021.4.0/licensing:/opt/intel/licenses:/root/intel/licenses:/Users/Shared/Library/Application Support/Intel/Licenses'
ENV INTEL_PYTHONHOME='/opt/intel/oneapi/debugger/10.2.4/dep'
ENV IPPCP_TARGET_ARCH='intel64'
ENV IPPCRYPTOROOT='/opt/intel/oneapi/ippcp/2021.4.0'
ENV IPPROOT='/opt/intel/oneapi/ipp/2021.4.0'
ENV IPP_TARGET_ARCH='intel64'
ENV I_MPI_ROOT='/opt/intel/oneapi/mpi/2021.4.0'
ENV LD_LIBRARY_PATH='/opt/intel/oneapi/vpl/2021.6.0/lib:/opt/intel/oneapi/tbb/2021.4.0/env/../lib/intel64/gcc4.8:/opt/intel/oneapi/mpi/2021.4.0//libfabric/lib:/opt/intel/oneapi/mpi/2021.4.0//lib/release:/opt/intel/oneapi/mpi/2021.4.0//lib:/opt/intel/oneapi/mkl/2021.4.0/lib/intel64:/opt/intel/oneapi/itac/2021.4.0/slib:/opt/intel/oneapi/ippcp/2021.4.0/lib/intel64:/opt/intel/oneapi/ipp/2021.4.0/lib/intel64:/opt/intel/oneapi/dnnl/2021.4.0/cpu_dpcpp_gpu_dpcpp/lib:/opt/intel/oneapi/debugger/10.2.4/gdb/intel64/lib:/opt/intel/oneapi/debugger/10.2.4/libipt/intel64/lib:/opt/intel/oneapi/debugger/10.2.4/dep/lib:/opt/intel/oneapi/dal/2021.4.0/lib/intel64:/opt/intel/oneapi/compiler/2021.4.0/linux/lib:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/x64:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/emu:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/oclfpga/host/linux64/lib:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/oclfpga/linux64/lib:/opt/intel/oneapi/compiler/2021.4.0/linux/compiler/lib/intel64_lin:/opt/intel/oneapi/ccl/2021.4.0/lib/cpu_gpu_dpcpp'
ENV LIBRARY_PATH='/opt/intel/oneapi/vpl/2021.6.0/lib:/opt/intel/oneapi/tbb/2021.4.0/env/../lib/intel64/gcc4.8:/opt/intel/oneapi/mpi/2021.4.0//libfabric/lib:/opt/intel/oneapi/mpi/2021.4.0//lib/release:/opt/intel/oneapi/mpi/2021.4.0//lib:/opt/intel/oneapi/mkl/2021.4.0/lib/intel64:/opt/intel/oneapi/ippcp/2021.4.0/lib/intel64:/opt/intel/oneapi/ipp/2021.4.0/lib/intel64:/opt/intel/oneapi/dnnl/2021.4.0/cpu_dpcpp_gpu_dpcpp/lib:/opt/intel/oneapi/dal/2021.4.0/lib/intel64:/opt/intel/oneapi/compiler/2021.4.0/linux/compiler/lib/intel64_lin:/opt/intel/oneapi/compiler/2021.4.0/linux/lib:/opt/intel/oneapi/clck/2021.4.0/lib/intel64:/opt/intel/oneapi/ccl/2021.4.0/lib/cpu_gpu_dpcpp'
ENV MANPATH='/opt/intel/oneapi/mpi/2021.4.0/man:/opt/intel/oneapi/itac/2021.4.0/man:/opt/intel/oneapi/debugger/10.2.4/documentation/man:/opt/intel/oneapi/compiler/2021.4.0/documentation/en/man/common:/opt/intel/oneapi/clck/2021.4.0/man::'
ENV MKLROOT='/opt/intel/oneapi/mkl/2021.4.0'
ENV NLSPATH='/opt/intel/oneapi/mkl/2021.4.0/lib/intel64/locale/%l_%t/%N'
ENV OCL_ICD_FILENAMES='libintelocl_emu.so:libalteracl.so:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/x64/libintelocl.so'
ENV ONEAPI_ROOT='/opt/intel/oneapi'
ENV PATH='/opt/intel/oneapi/vtune/2021.7.1/bin64:/opt/intel/oneapi/vpl/2021.6.0/bin:/opt/intel/oneapi/mpi/2021.4.0//libfabric/bin:/opt/intel/oneapi/mpi/2021.4.0//bin:/opt/intel/oneapi/mkl/2021.4.0/bin/intel64:/opt/intel/oneapi/itac/2021.4.0/bin:/opt/intel/oneapi/intelpython/latest/bin:/opt/intel/oneapi/intelpython/latest/condabin:/opt/intel/oneapi/inspector/2021.4.0/bin64:/opt/intel/oneapi/dev-utilities/2021.4.0/bin:/opt/intel/oneapi/debugger/10.2.4/gdb/intel64/bin:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/oclfpga/llvm/aocl-bin:/opt/intel/oneapi/compiler/2021.4.0/linux/lib/oclfpga/bin:/opt/intel/oneapi/compiler/2021.4.0/linux/bin/intel64:/opt/intel/oneapi/compiler/2021.4.0/linux/bin:/opt/intel/oneapi/clck/2021.4.0/bin/intel64:/opt/intel/oneapi/advisor/2021.4.0/bin64:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
ENV PKG_CONFIG_PATH='/opt/intel/oneapi/vtune/2021.7.1/include/pkgconfig/lib64:/opt/intel/oneapi/vpl/2021.6.0/lib/pkgconfig:/opt/intel/oneapi/tbb/2021.4.0/env/../lib/pkgconfig:/opt/intel/oneapi/mpi/2021.4.0/lib/pkgconfig:/opt/intel/oneapi/mkl/2021.4.0/lib/pkgconfig:/opt/intel/oneapi/ippcp/2021.4.0/lib/pkgconfig:/opt/intel/oneapi/inspector/2021.4.0/include/pkgconfig/lib64:/opt/intel/oneapi/dpl/2021.5.0/lib/pkgconfig:/opt/intel/oneapi/dal/2021.4.0/lib/pkgconfig:/opt/intel/oneapi/compiler/2021.4.0/lib/pkgconfig:/opt/intel/oneapi/ccl/2021.4.0/lib/pkgconfig:/opt/intel/oneapi/advisor/2021.4.0/include/pkgconfig/lib64:'
ENV PYTHONPATH='/opt/intel/oneapi/advisor/2021.4.0/pythonapi'
ENV SETVARS_COMPLETED='1'
ENV SETVARS_VARS_PATH='/opt/intel/oneapi/vtune/latest/env/vars.sh'
ENV TBBROOT='/opt/intel/oneapi/tbb/2021.4.0/env/..'
ENV VTUNE_PROFILER_2021_DIR='/opt/intel/oneapi/vtune/2021.7.1'
ENV VT_ADD_LIBS='-ldwarf -lelf -lvtunwind -lm -lpthread'
ENV VT_LIB_DIR='/opt/intel/oneapi/itac/2021.4.0/lib'
ENV VT_MPI='impi4'
ENV VT_ROOT='/opt/intel/oneapi/itac/2021.4.0'
ENV VT_SLIB_DIR='/opt/intel/oneapi/itac/2021.4.0/slib'
ENV _CE_CONDA=''
ENV _CE_M=''

USER buildbot
ENTRYPOINT ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
