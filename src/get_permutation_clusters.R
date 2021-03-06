get_clusters <- function(t_values,
                         condition,
                         sliding_method = "cross_correlation",
                         clustering_method = "euclidean",
                         max_distance = 3.5,
                         alpha = 0.05,
                         n = 11,
                         min_cluster_size = 2) {
  
  ## DESCRIPTION:
  ##  Identify clusters of spatially contiguous channels that show condition-dependent verdicality
  ## 
  ## INPUT:
  ##  condition (string) - "constraint", "meaning", or "talker"
  ##  sliding_method (string) - "cross_correlation", "convolution" (optional, default = "cross_correlation")
  ##  clustering_method (string) - "euclidean", "rank", or "density" (optional, default = "euclidean")
  ##  max_distance (double) - max_distance between neighboring electrodes, see histogram function (optional, default = 3.5)
  ##  alpha (double) - significance level at which to include channels in clusters (optional, default = 0.05)
  ##  n (int) - sample size (optional, default = 11)
  ##  min_cluster_size (int) - smallest cluster size to output (optional, default = 2)
  ##
  ## OUTPUT:
  ##  (list) - list of lists containing the numbers of channels in each cluster

  
  ## FUNCTIONS:
  library(dplyr) 
  
  get_coordinates <- function() {
    coordinates_fp <- file.path("/Applications/eeglab2019/talker-change-data-processing/data/aggregate/average_channel_locations.sfp")
    coordinates <- read.delim(coordinates_fp, header = FALSE, sep = "", dec = ".") %>%
      .[startsWith(as.character(.$V1), "E"), ] %>%
      .[c("V2", "V3", "V4")]
    names(coordinates) <- c("x", "y", "z")
    
    # Return
    return(coordinates)
  }
  
  
  get_pairwise_distances <- function(coordinates) {
    distances <- as.matrix(dist(coordinates))
    
    # Return
    return(distances)
  }
  
  
  get_histogram_of_pairwise_distances <- function(distances) {
    sort_distances = as.vector(distances) %>%
      .[!duplicated(.)] %>%
      sort() %>%
      hist(., breaks = 50, main = "Histogram of pairwise distances")
  }
  
  
  get_neighboring_clusters <- function(t_values, max_distance, alpha, n, distances) {
    # Determine threshold for t-values based on specified alpha level
    t_threshold <- qt(1-(alpha/2), df = n-1)
    
    # Identify neighboring above-threshold channels of all above-threshold channels
    clusters <- vector(mode = "list")
    for (i in 1:nrow(distances)) {
      
      # Check whether channel itself is above threshold
      if (abs(t_values[i]) > t_threshold) {
        
        # Identify all neighboring channels within the specified max_distance
        neighboring_channels = which(distances[i, ] < max_distance)
        
        # Keep above-threshold neighbors
        indexes = which(abs(t_values[neighboring_channels]) > t_threshold)
        clusters_for_one_channel = list(neighboring_channels[indexes])
        
        # Exclude channels whose only active neighbor is itself
        if (length(clusters_for_one_channel[[1]]) > 1) {
          clusters = c(clusters, clusters_for_one_channel)
        }
      } 
    }
    # Return
    return(clusters)
  }

    get_actual_clusters <- function(clusters) {
      
      # Compare every cluster to every other cluster
      for (i in 1:length(clusters)) {
        cluster_a <- clusters[[i]]
        
        # Loop through every cluster
        for (j in 1:length(clusters)) {
          cluster_b <- clusters[[j]]
          
          # Compare the two clusters...
          combined <- c(cluster_a, cluster_b)
          
          # If there are duplicates...
          if (TRUE %in% duplicated(combined) & (j > i)) { 
            
            # Set the original cluster into the merged cluster
            clusters[[i]] <- unique(combined)
            
            # Set the compared cluster to null
            clusters[[j]] <- 0
          }
        }
      }
        
      # Remove all clusters smaller than min_cluster_size, remove 0s
      keep = vector(mode = "list")
      for (i in 1:length(clusters)) {
        cluster = clusters[[i]]
        if (length(cluster) >= min_cluster_size) {
          keep <- c(keep, list(cluster))
        }
      }
      clusters <- keep
      
      # Return if all possible clusters are created
      if (!(TRUE %in% duplicated(unlist(clusters)))) {
        return(clusters)
      }
      
      # Recursively apply function
      return(get_actual_clusters(clusters))
    }

  
    ## MAIN:
    coordinates <- get_coordinates()
    distances <- get_pairwise_distances(coordinates)
    neighboring_clusters <- get_neighboring_clusters(t_values, max_distance, alpha, n, distances)
    clusters <- get_actual_clusters(neighboring_clusters)
    
    
    ## SAVE:
    file_name <- paste(sliding_method, "_", condition, "_clusters.txt", sep = "")
    if (file.exists(file_name)) {file.remove(file_name)}
    for (i in 1:length(clusters)) {
      write(clusters[[i]], file = file_name, append = TRUE, ncolumns = 128)
    }
    
    
    ## RETURN:
    return(clusters)
  }


