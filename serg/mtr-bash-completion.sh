_mtr_complete_testnames ()
{
  dir="$1"
  [ -d "$dir"/t ] && dir="$dir"/t
  testnames=$( cd "$dir" && echo *.test | sed -e 's/\.test\>//g' )
}
_mtr_all_suites ()
{
  suites=$(find "$sourcetestdir"/suite "$sourcetestdir"/../{storage,plugin}/*/mysql-test -type d -exec find '{}' -maxdepth 1  -name '*.test' -print -quit \; | sed -E "s@^$sourcetestdir/(suite|\.\./storage|\.\./plugin)/@@"'; s@/mysql-test@@; s@(/t)?/[^/]+\.test$@@'|sort -u)
}
_mtr_complete()
{
  sourcetestdir=$(sed -n -e "/^chdir/s/[^']*'\(.*\)');$/\1/p" < "$1")
  cur=$2
  prev=$3
  case $prev:$cur in
    *:--*)
      opts=$( "$1" --list )
      COMPREPLY=( $( compgen -W "$opts" -- $cur) )
      ;;
    *:main.*)
      [ -d "${sourcetestdir}/main" ] && dir="${sourcetestdir}/main" || dir="${sourcetestdir}"
      _mtr_complete_testnames "$dir"
      COMPREPLY=( $( compgen -P ${cur%.*}. -W "$testnames" -- ${cur#*.}) )
      ;;
    *:?*.*)
      for dir in "${sourcetestdir}"/{suite,../{storage,plugin}/*/mysql-test}/${cur%.*}; do
        if [ -d $dir ]; then
          _mtr_complete_testnames $dir
          break
        fi
      done
      COMPREPLY=( $( compgen -P ${cur%.*}. -W "$testnames" -- ${cur#*.}) )
      ;;
    --suite:*)
      _mtr_all_suites
      compopt -o nospace
      COMPREPLY=( $( compgen -S , -W "$suites" -- ${cur##*,}) )
      local prefix=
      [[ $cur == *,* ]] && prefix=${cur%,*},
      [[ ${#COMPREPLY[@]} == 1 ]] && COMPREPLY=( $prefix$COMPREPLY )
      ;;
    *)
      _mtr_all_suites
      compopt -o nospace
      COMPREPLY=( $( compgen -S . -W "$suites" -- $cur) )
      ;;
  esac
}
complete -F _mtr_complete mtr
