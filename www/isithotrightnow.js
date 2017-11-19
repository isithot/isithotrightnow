/* Is it hot right now?
   Code for loading in local weather stats (on page load and on location update)
   James Goldie, Steefan Contractor & Mat Lipson 2017 */

  /* on page load: choose a location (for now, Sydney Obs Hill), download
     assets and insert */
  $(function()
  {
    default_location = "IDN60901.94768";
    default_path =
      "output/" + default_location + "/";
    loaded_resources = 
    {
      isit_stats: false,
      isit_ts_plot: false,
      isit_density_plot: false
    }
    
    // dl stats as json and insert on success.
    // (nb: no error callback available! need to use a timeout below)
    $.getJSON(default_path + "stats.json", function(data)
    {
      $("#isit_answer").text(data.isit_answer);
      $("#isit_comment").text(data.isit_comment);

      $("#isit_current").text(data.isit_current);
      $("#isit_average").text(data.isit_average);

      loaded_resources.isit_stats = true;

      // enable page if all resources are loaded
      if (loaded_resources.every(function(x) { return x; }))
      {
        $("#detail").attr("style", "display: flex;");
        $("#digdeeper").attr("style", "color: #b22222;");
        $("#digdeeper h3").text("Dig deeper");
      }
    });
    
    // dl *each* image and insert on success
    plots = ["ts_plot", "density_plot"]
    $.each(plots, function(index, content)
    {
      var plot_target = $("#isit_" + content + " img");
      var plot_building = $("<img>");
      plot_building.load(function()
      {
        // when loading img is ready, set it to the target img
        plot_target.attr("src", $(this).attr("src"));

        // enable page if all resources are loaded
        if (loaded_resources.every(function(x) { return x; }))
        {
          $("#detail").attr("style", "display: flex;");
          $("#digdeeper").attr("style", "color: #b22222;");
          $("#digdeeper h3").text("Dig deeper");
        }
      });
      // set loading img src to trigger the download
      plot_building.attr("src", default_path + content + ".png");  

      loaded_resources["isit_" + content] = true;
    });

    // apologise if resources aren't all loaded after 10 secs
    setTimeout(function()
    {
      if (!loaded_resources.every(function(x) { return x; }))
      {
        $("#digdeeper h3").text("We're having some trouble downloading the data... 😅");
      }  
    }, 10000);

  });