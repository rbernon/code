_git_pab ()
{
  if [ "${prev}" = "pab" ]; then
    __gitcomp_nl "$(__git_remotes)"
  else
    __gitcomp_nl "$(__git_heads)"
  fi
}
