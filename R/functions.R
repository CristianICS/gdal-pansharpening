# Source: https://stackoverflow.com/a/21313276
# After writing this function I've learned
# that iterators are very inefficient in R.
packages = c("iterators", 'itertools')

package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = T)) {
      install.packages(x, dependencies = T)
      library(x, character.only = T)
    }
  }
)
library("iterators")
# install.packages("itertools")
library("itertools")

path.cat<-function(...)
{
  # High-level function that inteligentely concatenates
  # paths given in arguments.
  # The user interface is the same as for file.path,
  # with the exception that it understands the path ".."
  # and it can identify relative and absolute paths.
  # Absolute paths starts comply with "^\/" or "^\d:\/" regexp.
  # The concatenation starts from the last absolute path in arguments,
  # or the first, if no absolute paths are given.

  elems<-list(...)
  elems<-as.character(elems)
  elems<-elems[elems!='' && !is.null(elems)]
  relems<-rev(elems)
  starts<-grep('^[/\\]',relems)[1]
  if (!is.na(starts) && !is.null(starts))
  {
    relems<-relems[1:starts]
  }
  starts<-grep(':',relems,fixed=TRUE)
  if (length(starts)==0){
    starts=length(elems)-length(relems)+1
  }else{
    starts=length(elems)-starts[[1]]+1}
  elems<-elems[starts:length(elems)]
  path<-do.call(file.path,as.list(elems))
  elems<-strsplit(path,'[/\\]',FALSE)[[1]]
  it<-ihasNext(iter(elems))
  out<-rep(NA,length(elems))
  i<-1
  while(hasNext(it))
  {
    item<-nextElem(it)
    if(item=='..')
    {
      i<-i-1
    } else if (item=='' & i!=1) {
      #nothing
    } else   {
      out[i]<-item
      i<-i+1
    }
  }
  do.call(file.path,as.list(out[1:i-1]))
}