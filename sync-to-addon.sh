#! /bin/bash

# Exit immediately on error
set -e
set -b

# Cannot simply copy the whole repo, or the whole dir. 
# The actual addon contains 3rd party libs that are not included in the github repo
# Hence, copy over only the specific files that I have modified
# This is needed since project maintainers have declined to incorporate my local features into their project

echo "##### Syncing changes to RETAIL addon"

echo "##### Removing original core/ui/options"
rm /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/Core.lua
rm /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/UI.lua
rm /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/Options/Options.lua

echo "##### Copying over my modified versions of core/ui/options"
cp Core.lua /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/
cp UI.lua /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/
cp Options/Options.lua /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/Options/

echo "##### Diffing copied files. Should see 0 diffs"
diff Core.lua /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/Core.lua
diff UI.lua /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/UI.lua
diff Options/Options.lua /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili/Options/Options.lua

echo "##### No diffs found. Success! Diffing entire dir as sanity-check. Expect to see some diffs here, esp for dotfiles and 3rd party libs"
diff -bur . /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/Hekili

