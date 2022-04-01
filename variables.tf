variable username {
   type = string 
}

variable secret_pwd {
    type = string
    sensitive = true
} 
variable name {
    type = string
}
variable location {
    type = string
    default = "West Europe"
}
variable computer_name {
    type = string
    default = "tarefa01"
}