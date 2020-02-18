_git_lmb ()
{
  # you can return anything here for the autocompletion for example all the branches
  __gitcomp_nl "-v
$(__git_heads)"
}
