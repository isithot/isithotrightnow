/* Is it hot right now?
   Code for loading in local weather stats (on page load and on location update)
   James Goldie, Steefan Contractor & Mat Lipson 2017 */

/* on page load: choose a location (for now, Sydney West), download
    assets and insert */
    
$(function()
{
  var default_station = "067105";
  var default_url = "sydney-west";
  var base_path = "/output/"
  var location_menu_innerpad = 10;
  var location_request_timeout = 5000;
  var geolocation_timeout = 1000;
  var geolocation_done = false;

  /* load_new_location: wrapper function for loading a new location. resizes the
    dropdown menu and starts requesting new station data. */
  load_new_location = function(station_id) {
    console.log(station_id);
    request_station(station_id);
  }

  /* request_station: hide the details section, download stats and plots
     for a new station and then display them _when they're ready_
     put up an error message if they don't load quickly enough */
  function request_station(station_id)
  {
  
    // fn and obj to track downloaded resources. should probably write a
    // self-contained object for this...
    var loaded_resources = 
    {
      isit_stats: false,
      isit_ts_plot: false,
      isit_density_plot: false,
      isit_heatmap: false,
    }
    function resources_loaded()
    {
      console.log(
        'Loading status...' +
        'Stats:\t\t\t\t' + loaded_resources.isit_stats +
        'Series\t\t\t\t:' + loaded_resources.isit_ts_plot +
        'Density:\t\t\t\t'  + loaded_resources.isit_density_plot +
        'Heatmap:\t\t\t\t' + loaded_resources.isit_heatmap);
      
      if (
        loaded_resources.isit_stats == false |
        loaded_resources.isit_ts_plot == false |
        loaded_resources.isit_density_plot == false |
        loaded_resources.isit_heatmap == false)
      {
        console.log('Still going...');
        return false;
      }
      else
      {
        console.log('Ready to go!')
        return true;
      }
    }

    // hide the details section while we update stuff!
    $("#detail").css("display", "none");
    $("#heatmap").css("display", "none");
    // update the status message
    $("#digdeeper_loading").css("display", "inline-block");
    $("#digdeeper_ok").css("display", "none");
    $("#digdeeper_error").css("display", "none");
    $("#digdeeper h3")
      .text("Calling 1-800-IS-IT-HOT...")
      .removeClass("msg_ok msg_error")
      .addClass("msg_loading");
    $("#isit_answer").text("");
    $("#isit_comment").text("");
    
    // dl stats as json and insert on success.
    // (nb: no error callback available! need to use a timeout below)
    $.getJSON(base_path + station_id + "/stats.json", function(data)
    {
      $("#isit_answer").text(data.isit_answer);
      $("#isit_comment").text(data.isit_comment);
      $("#isit_maximum").text(data.isit_maximum);
      $("#isit_minimum").text(data.isit_minimum);
      $("#isit_current").text(data.isit_current);
      $("#isit_average").text(data.isit_average);
      $("#isit_name_detail").text(data.isit_name);
      $("#isit_name_heatmap").text(data.isit_name);
      $("#isit_span").text(data.isit_span);

      loaded_resources.isit_stats = true;

      // enable page if all resources are loaded
      if (resources_loaded())
      {
        // if($.grep(
        //   [$("#isit_maximum").text(), $("#isit_minimum").text(),
        //     $("#isit_current").text(), $("#isit_average").text() ],
        //   function(el) { return el == "" || el == "NaN" || el == "NA"; }).length == 0)
        // {
        //   // problem with the data: display an error
        //   console.log('Isithot: Uh oh, these stats look weird');
        //   $("#digdeeper_loading").css("display", "none");
        //   $("#digdeeper_ok").css("display", "none");
        //   $("#digdeeper_error").css("display", "inline-block");
        //   $("#digdeeper h3")
        //     .text("The data we're getting looks a little weird! " +
        //       "That's probably something on our end, sorry.")
        //     .removeClass("msg_loading msg_ok")
        //     .addClass("msg_error");

        // } else {
          // all good! update the status message...
          console.log('Revealing the page!');
          $("#digdeeper_loading").css("display", "none");
          $("#digdeeper_error").css("display", "none");
          $("#digdeeper_ok").css("display", "inline-block");
          $("#digdeeper h3")
            .text("Dig deeper")
            .removeClass("msg_loading msg_error")
            .addClass("msg_ok");
          // ... and bring it up
          $("#detail").css("display", "flex");
          $("#heatmap").css("display", "flex");
        // }
      }
    });
    
    // dl *each* image and insert on success
    // NB: strings in this array are directed appended to "isit_" to find
    // target dom ids!
    plots = ["ts_plot", "density_plot", "heatmap"]
    plots.map(function(content)
    {
      var plot_target = $("#isit_" + content + " img");
      console.log('Isithot: Creating callback to load ' + content);
      var plot_building = $("<img>");
      plot_building.on('load', function()
      {
        console.log('Isithot: Inside onload callback for dummy ' + content);
        // when loading img is ready, set it to the target img
        plot_target.attr("src", $(this).attr("src"));

        // enable page if all resources are loaded
        if (resources_loaded())
        {
          // if($.grep(
          //   [$("#isit_maximum").text(), $("#isit_minimum").text(),
          //     $("#isit_current").text(), $("#isit_average").text() ],
          //   function(el) { return el == "" || el == "NaN" || el == "NA"; }).length > 0)
          // {
            // problem with the data: display an error
            // $("#digdeeper_loading").css("display", "none");
            // $("#digdeeper_ok").css("display", "none");
            // $("#digdeeper_error").css("display", "inline-block");
            // $("#digdeeper h3")
            //   .text("The data we're getting looks a little weird! " +
            //     "That's probably something on our end, sorry.")
            //   .removeClass("msg_loading msg_ok")
            //   .addClass("msg_error");
  
          // } else {
            // all good! update the status message...
          console.log('Revealing the page!');
          $("#digdeeper_loading").css("display", "none");
          $("#digdeeper_error").css("display", "none");
          $("#digdeeper_ok").css("display", "inline-block");
          $("#digdeeper h3")
            .text("Dig deeper")
            .removeClass("msg_loading msg_error")
            .addClass("msg_ok");
          // ... and bring it up
          $("#detail").css("display", "flex");
          $("#heatmap").css("display", "flex");
          // }
        }
      });
      // set loading img src to trigger the download
      plot_building.attr(
        "src", base_path + station_id + "/" + content + ".png");
      console.log('Isithot: Set src attribute for ' + content + '; image ought to be loading now');

      loaded_resources["isit_" + content] = true;
    });

    // apologise if resources aren't all loaded after 10 secs
    setTimeout(function()
    {
      if (!resources_loaded())
      {
        console.log('Timeout expired; hiding the page and throwing an error');
        $("#digdeeper_loading").css("display", "none");
        $("#digdeeper_ok").css("display", "none");
        $("#digdeeper_error").css("display", "inline-block");
        $("#digdeeper h3")
          .text("We're having some trouble downloading the data...")
          .removeClass("msg_loading msg_ok")
          .addClass("msg_error");
      }  
    }, location_request_timeout);
  }

  /* resize_location_menu: resize the location menu according to the
     current selection */
  function resize_location_menu(new_text)
  {
    // resize the dropdown
    console.log('Resizing dropdown menu');
    $("#current_location_temp_dummyopt").html(new_text);
    $("#current_location").width(
      $("#current_location_temp").width() + location_menu_innerpad);
  }

  /* geo_failure: requests the nearest station id */
  function geo_success(pos_data) {
    if (pos_data.country_name != "Australia") {
      console.warn("User outside Australia; use default site");
      load_new_location(default_station);
      $("#current_location").val(default_url);
    }
    else {
      switch (pos_data.state_prov) {
        case 'Australian Capital Territory':
          load_new_location("070351");
          $("#current_location").val("canberra");
          break;
        case 'New South Wales':
          load_new_location("067105");
          $("#current_location").val("sydney-west");
          break;
        case 'Victoria':
          load_new_location("067105");
          $("#current_location").val("sydney-west");
          break;
        case 'Tasmania':
          load_new_location("094029");
          $("#current_location").val("hobart");
          break;
        case 'Queensland':
          load_new_location("040842");
          $("#current_location").val("brisbane");
          break;
        case 'South Australia':
          load_new_location("067105");
          $("#current_location").val("sydney-west");
          break;
        case 'Northern Territory':
          load_new_location("014015");
          $("#current_location").val("darwin");
          break;
        case 'Western Australia':
          load_new_location("009021");
          $("#current_location").val("perth");
          break;
        default:
          console.warn(
            "User region not recognised; " + 
            "defaulting to Sydney West");
          load_new_location(default_station);
          $("#current_location").val(default_url);
      }
    }
    console.log("Geolocation done!");
    geolocation_done = true;
    $("#current_location").change(function() {
      location = "/" + this.value;
    });
    resize_location_menu($("#current_location option:selected").text());
  }

  /* geo_failure: requests the sydney obs hill station id */
  function geo_failure()
  {
    console.warn("Geolocation failed; defaulting to Sydney Obs Hill!");
    load_new_location(default_station);
    $("#current_location").val(default_url);
    $("#current_location").change(function() {
      location = "/" + this.value;
    });
    resize_location_menu($("#current_location option:selected").text());
  }

  // = on page load ===========================================================

  $.getJSON("/locations.json", function(data)
  {

    // 1. populate the location menu
    $.each(data, function(index, station) {
      $("#current_location").append(
        '<option value="' + station.url + '">' + station.label + '</option>');
    });

    // 2. if this is the home page, try to geolocate and use that to find a
    // place; if it isn't, match the url against locations.json
    if (window.location.pathname == "/") {

      if (navigator.geolocation)
        {
          // $.get("http://api.ipstack.com/check?access_key=35ea05193a4d09447dce431efb17d196&format=1", geo_success);
          $.get("https://api.ipgeolocation.io/ipgeo?apiKey=637ffd1cb9094542970a103e731f76d4&fields=country_name,state_prov", geo_success);
        } 
        else
        {
          console.warn("No geolocation available!");
        }

        // default to sydney if geolocation hasn't returned
        setTimeout(function()
        {
          if (!geolocation_done)
          {
            geo_failure();
          }  
        }, geolocation_timeout);

    } else {
    
      var subpage = window.location.pathname.split("/")[1]
      var match_found = false;
      $.each(data, function(index, station) {
        if (station.url == subpage) {
          match_found = true;
          load_new_location(station.id);
          $("#current_location").val(station.url);
          $("#current_location").change(function() {
            location = "/" + this.value;
          });
          resize_location_menu($("#current_location option:selected").text());
        }
      });
      if (!match_found) {
        console.warn("The URL \"" + subpage + "\" isn't in /locations.json.")
      }
    }
  });
});

