
#' Validate meta file based on schema.
#'
#' @param meta  Name of meta file.
#'
#' @return Warnings and errors (if any).
#' @author Lars Relund \email{lars@@relund.dk}
checkMeta<-function(meta) {
   schema<-system.file("metaSchema.json", package = "MOrepoTools")
   jsonvalidate::json_validate(meta,schema, verbose = TRUE, error = TRUE)
}


#' Function of asking questions.
#'
#' @param ...  Question string.
#'
#' @return True if yes and false otherwise.
#' @author Lars Relund \email{lars@@relund.dk}
yesno<-function (...)
{
   yeses <- c("Yes", "Yup", "Yeah")
   nos <- c("No", "Nope")
   message(paste0(..., collapse = ""))
   qs <- c(sample(yeses, 1), sample(nos, 1))
   rand <- sample(length(qs))
   utils::menu(qs[rand]) == which(rand == 1)
}


#' Check if a contribution convey with the guidelines.
#'
#' You must run this function in the root of your contribution.
#'
#' @author Lars Relund \email{lars@@relund.dk}
#' @export
checkContribution<-function() {
   message("Your working directory is ", getwd())
   if (!yesno("Is that the location of your contribution?")) {
      message("\n   Error: Change working directory!")
      return(invisible(FALSE))
   }

   # Encoding
   if (!yesno("\nAre files citation.bib and meta.json saved using encoding UTF-8?")) {
      message("\n   Error: You need to save them using UTF-8!")
      return(invisible(FALSE))
   }

   message("Checking meta file content ...", appendLF = FALSE)
   if (!file.exists("meta.json")) {
      message("\n   Error: You need to add a file meta.json!")
      return(invisible(FALSE))
   }
   checkMeta("meta.json")
   meta<-jsonlite::fromJSON("meta.json")
   if (meta$contributionName != sub("MOrepo-", "", basename(getwd()))) {
      message("\n   Error: The contributionName entry in meta.json is not a part of the folder name of the contribution!")
      return(invisible(FALSE))
   }
   message(" ok.")

   message("Checking for missing files ...", appendLF = FALSE)
   if (!file.exists("citation.bib")) {
      message("\n   Error: You need to add a file citation.bib!")
      return(invisible(FALSE))
   }
   if (!file.exists("ReadMe.md")) {
      message("\n   Error: You need to add a file ReadMe.md in the root!")
      return(invisible(FALSE))
   }
   message(" ok.")

   message("Checking citation.bib ...", appendLF = FALSE)
   RefManageR::ReadBib("citation.bib")
   message(" ok.")

   if ("instances" %in% list.dirs(full.names = FALSE, recursive = FALSE)) {
      message("Your contribution contains test instances. ")
      # if (!file.exists("instances/ReadMe.md")) {
      #    message("\n   Error: You need to add a file ReadMe.md in the instances folder!")
      #    return(invisible(FALSE))
      # }
      message("Checking file and folders structure in instances ...", appendLF = FALSE)
      # Subfolders for each file format
      if (!all(unlist(meta$instanceGroups$format) %in% list.dirs(path = "./instances", full.names = FALSE, recursive = FALSE))) {
         message("\n   Error: The instances folder must have a subfolder for each instance file format (",
                 paste0(meta$instanceGroups$format[[1]], collapse = ", "), ") specified in the meta.json file.")
         return(invisible(FALSE))
      }
      # Subfolders in each file format folder (from meta.json)
      for (i in 1:length(meta$instanceGroups$subfolder)) {
         if (meta$instanceGroups$subfolder[i]=="") next
         for (f in meta$instanceGroups$format[[i]]) {
            if (!(meta$instanceGroups$subfolder[i] %in% list.dirs(path = paste0("./instances/",f), full.names = FALSE, recursive = FALSE))) {
               message("\n   Error: The format folder ", f, " must have a subfolder named ", meta$instanceGroups$subfolder[i], " as specified in the meta.json file.")
               return(invisible(FALSE))
            }
         }
      }
      # Subfolders for each file format contains the same file names except file extension
      dat <- NULL
      for (s in meta$instanceGroups$subfolder) {
         for (f in meta$instanceGroups$format[[i]]) {
            files <- basename(list.files(path = paste0("./instances/", f, "/", s) , recursive = FALSE, full.names = FALSE))
            files <- sub("\\..*.$","",files)
            dat <- c(dat,files)
         }
         if (!all(data.frame(table(files))$Freq >= length(meta$instanceGroups$format[[i]]))) {
            message("\n   Error: The each instance file folder ", s,
                    ") must contain the same file names (with different file extension).")
            return(invisible(FALSE))
         }
      }
      # Folder name used as prefix for all instances
      for (f in meta$instanceGroups$format[[1]]) {
         if (length(grep(meta$contributionName, basename(list.files(paste0("./instances/",f), recursive = TRUE)), invert = TRUE))>0) {
            message("\n   Error: Files in folder ", f, " must all start with prefix ", meta$contributionName, "!")
            return(invisible(FALSE))
         }
      }
      # Subfolder name contained in filename for all instances
      for (f in meta$instanceGroups$format[[1]]) {
         for (d in meta$instanceGroups$subfolder)
            if (length(grep(d, list.files(paste0("./instances/",f,"/",d)), invert = TRUE))>0) {
               message("\n   Error: Filenames in subfolder ", d, " must all contain ", d, "!")
               return(invisible(FALSE))
            }
      }
      # Only files with the file format suffix
      for (f in meta$instanceGroups$format[[1]]) {
         if (!all(f == tools::file_ext(basename(list.files(paste0("./instances/",f), recursive = TRUE))))) {
            message("\n   Error: All files in folder ", f, " must end with file suffix ", f, "!")
            return(invisible(FALSE))
         }
      }
      message(" ok.")
   }

   if ("results" %in% list.dirs(full.names = FALSE, recursive = FALSE)) {
      message("Your contribution contains results of test instances. ")
      files <- list.files(path = "results", pattern = ".json$", all.files = TRUE, recursive = TRUE, full.names = TRUE )
      message("Validate the result files against schema ... ")
      for (f in files) {
         message("Validate ", f, " ...", appendLF = FALSE)
         checkResult(f)
         message(" ok.")
      }
      message("Check if there is an instance file in MOrepo for each result file ... ", appendLF = FALSE)
      instances <- getMetaInstances()
      res <- sapply(files, function(x) {
         name <- basename(x)
         name <- sub("(.*)_result.*$", "\\1", name)
         if (!(name %in% instances$instanceName)) {
            message("\n   Error: File ", x, " does not correspond to and instance file!")
            return(FALSE)
         } else return(TRUE)
      })
      if (all(res) == FALSE) return(invisible(FALSE))
      message(" ok.")
   }

   message("Everything seems to be okay :-)")
}
