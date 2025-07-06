# this is a dotnu-embeds file. When updated using `dotnu embeds-update`, it will update `# =>` lines with the result of `print $in`.

# example long command
let base_dir = "/Users/user/git/nushell-history-based-completions"; cd $base_dir; let target_dir = 'nutest'; ls (pwd | path dirname | path join $target_dir) --all | each {|i| $i.name | str upcase} | first 2 | enumerate | table --theme rounded | print $in

# => ╭─#─┬──────────────item──────────────╮
# => │ 0 │ /USERS/USER/GIT/NUTEST/.GIT    │
# => │ 1 │ /USERS/USER/GIT/NUTEST/.GITHUB │
# => ╰─#─┴──────────────item──────────────╯

ast --flatten --json r#'let base_dir = "/Users/user/git/nushell-history-based-completions"; cd $base_dir; let target_dir = 'nutest'; ls (pwd | path dirname | path join $target_dir) --all | each {|i| $i.name | str upcase} | first 2 | enumerate | table --theme rounded | print $in'#
| to json
| save --raw --force ($base_dir | path join parser_test_cases complex_pipeline_ast_flattened.json)
