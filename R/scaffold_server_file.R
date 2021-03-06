
create_server_file<-function(input_list,file_name="server.r",datastore_type="file_based"){

  checkmate::assert_list(input_list)
  checkmate::assert_names(names(input_list),must.include = c('type','id','label'))
  checkmate::assert_character(datastore_type)
  checkmate::assert_character(file_name)

  start<-"function(input, output, session) {\n"
  end<-"\n}"

  data_function<-create_data_function(input_list)

  if(datastore_type=="file_based"){
  save_path="my_file.csv"
  writeLines("",save_path) #initialize file ? Should it be in global.r
  save_function<-create_save_function_file(save_path)
  retrieve_function<-create_retrieve_data_function_file(save_path)
  }else if(datastore_type=="sqllite"){
    save_function<-create_save_function_db()
    retrieve_function<-create_retrieve_data_function_db()
  }else{
    stop("Only file based saving supported")
  }

  display_data_function<-create_display_data_table_function()
  download_function<-create_download_function()
  file_content<-paste0(start,data_function,
                       save_function,
                       retrieve_function,
                       display_data_function,
                       download_function,
                       end)
  writeLines(file_content,file_name)

  if(file.exists(file_name)){
    message("server file created\n")
  }else{
    warning("server file not created\n")
  }
}

create_data_function<-function(input_list){

  # create a tibble from the specified input list

  x<-paste0(input_list$id,"=input$",input_list$id,collapse=",\n")
  start<-"dataset_to_save<-reactive({\nmy_data <- tibble(\n"
  end<-")\n return(my_data)})"
  data_function<-paste0("\n",start,x,end,"\n")

  return(data_function)
}

create_save_function_file<-function(save_path){

  start<-"\nregisterData<-observeEvent(input$save,{\n
  my_dataset<-dataset_to_save()\n
  withProgress(message=\"Registering\",value=0.2,{"

  x<-paste0("\nif(file.size(\"",save_path,"\")>10){
            write_csv(my_dataset,path=\"",save_path,"\",append = TRUE)
}else{
            write_csv(my_dataset,path=\"",save_path,"\",append = FALSE)
}\n")

  end<-"}) \n showModal(modalDialog(\n
  title = \"Thank you!\",
  \"Data has been saved\"
  ))
  })"

  save_function<-paste0(start,x,end,"\n")
  return(save_function)
}


create_save_function_db<-function(){

  start<-start<-"\nregisterData<-observeEvent(input$save,{\n
  my_dataset<-dataset_to_save()\n
  withProgress(message=\"Registering\",value=0.2,{"

  x<-paste0("
         dbWriteTable(conn, datatable, my_dataset,append=TRUE)
   ")



  end<-"}) \n showModal(modalDialog(\n
  title = \"Thank you!\",
  \"Data has been saved\"
  ))
})"

  save_function<-paste0(start,x,end,"\n")
  return(save_function)

}

# retrieve data

create_retrieve_data_function_db<-function(){

  x<-"allData<-function(){

    my_data<-tbl(conn,datatable)%>%collect()
    shiny::validate(need(nrow(my_data)>0,\"no data\"))
    return(my_data)
  }"
  return(x)

}

create_retrieve_data_function_file<-function(save_path){


  retrieve_data<-glue::glue("allData <- reactiveFileReader(1000, session,","\"",save_path,"\"",",\"read_csv\")")
  return(retrieve_data)
}
# display data

create_display_data_table_function<-function(){

  table_function<-"\noutput$data <- DT::renderDataTable({

  data<-allData()

  data<-data%>%select(
  everything())

  DT::datatable(data,  selection = \'single\',
  filter=\'top\',
  rownames= FALSE,
  escape=FALSE,
  options = list(
  scrollX = TRUE)
  )
})"

  return(table_function)
  }

create_download_function<-function(){

  download_function<- "\noutput$download_data <- downloadHandler(
  filename = function() {
  paste(\"download_data\", \".csv\", sep = \"\")
  },
  content = function(file) {
  write_csv(allData(), file)
  }
  )"

  return(download_function)

}
