function ren_pics(){
cur_dir=$(basename "$PWD") && exiv2 -r"$cur_dir"' - %Y-%m-%d %H.%M.%S' -F rename *;
}
export -f ren_pics
