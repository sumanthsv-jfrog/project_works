resource "platform_permission" "my_new_permission" {
  name = "developers-permission"

  artifact = {
    targets = [
      {
        name             = "my-new-repo"
        include_patterns = ["**"]
        exclude_patterns = [""]
        operations       = ["READ", "WRITE", "ANNOTATE"]
      }
    ]
    principals = {
      groups = [
        {
          name       = "developers"
          operations = ["READ", "WRITE", "ANNOTATE"]
        }
      ]
    }
  }
}
