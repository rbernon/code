_git_rab ()
{
  # you can return anything here for the autocompletion for example all the branches
  __gitcomp_nl "$(__git_heads)"
}
