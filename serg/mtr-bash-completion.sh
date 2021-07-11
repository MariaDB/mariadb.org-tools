_mtr_complete_testnames ()
{
  dir=$1
  [ -d $dir/t ] && dir=$dir/t
  testnames=$( cd $dir && echo *.test | sed -e 's/\.test\>//g' )
}
_mtr_all_suites ()
{
  suites=$(find suite ../{storage,plugin}/*/mysql-test -type d -exec find '{}' -maxdepth 1  -name '*.test' -print -quit \; | sed -E 's@/(t/)?[^/]+$@@; s@^(suite|.*/mysql-test)/@@'|sort -u)
}
_mtr_complete()
{
  [ -x ./mtr ] || return
  [ -d main ] && main=main || main=.
  cur=$2
  prev=$3
  case $prev:$cur in
    *:--*)
      opts=$( ./mtr --list )
      COMPREPLY=( $( compgen -W "$opts" -- $cur) )
      ;;
    *:main.*)
      _mtr_complete_testnames $main
      COMPREPLY=( $( compgen -P ${cur%.*}. -W "$testnames" -- ${cur#*.}) )
      ;;
    *:?*.*)
      for dir in {../{storage,plugin}/*/mysql-test,suite}/${cur%.*}; do
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
