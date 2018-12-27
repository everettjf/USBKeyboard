dir=$(pwd)
echo $dir

ln -s $dir/proto $dir/ios/proto 
ln -s $dir/proto $dir/macos/proto

echo "done!"

