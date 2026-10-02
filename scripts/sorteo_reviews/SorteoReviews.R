# Load required library
library(dplyr)

# Create a vector of 12 mentors names
mentors <- c("Elio", "Maëlle", "Andrea", "Paola", "Francisco", "Luis", "Yanina", "Pablo", "Monika", "Erick", "Guadalupe", "Alber")

champions <- Champions_2026_2027$name

# Function to assign reviewers
assign_reviewers <- function(mentors, champions) {
  # Create a dataframe to store assignments
  assignments <- data.frame(Champion = champions, Reviewer1 = NA, Reviewer2 = NA)
  
  # Calculate the total number of reviews each mentor needs to perform
  total_reviews <- length(champions) * 2
  reviews_per_mentor <- total_reviews %/% length(mentors)
  
  # Check if the assignment is possible
  # if (total_reviews %% length(mentors) != 0) {
  #   stop("The number of reviews cannot be evenly distributed among mentors.")
  # }
  
  # Duplicate the mentor list to match the total reviews required
  mentor_pool <- rep(mentors, times = reviews_per_mentor)
  
  # Shuffle the mentor pool to ensure randomness
  set.seed(123) # For reproducibility, you can remove this line for true randomness
  mentor_pool <- sample(mentor_pool)
  
  # Assign reviewers
  for (i in seq_along(champions)) {
    assignments$Reviewer1[i] <- mentor_pool[1]
    assignments$Reviewer2[i] <- mentor_pool[2]
    
    # Remove assigned mentors to avoid duplication
    mentor_pool <- mentor_pool[-c(1, 2)]
  }
  
  return(assignments)
}


result <- assign_reviewers(mentors, champions)

misma_persona <- result |> 
  filter(Reviewer1 == Reviewer2)


write.csv(result, file = "reviewers_assignments.csv")
