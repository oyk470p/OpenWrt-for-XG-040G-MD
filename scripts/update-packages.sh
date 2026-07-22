#!/bin/bash
# 安装和更新第三方软件包
# 此脚本在 openwrt/package/ 目录下运行，在 feeds install 之后执行
UPDATE_FEED_PACKAGE() {  
    local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local GIT_URL="https://github.com/$PKG_REPO.git" 
	local FEED_DIR="../myluci"
    echo "Installing $PKG_NAME from $GIT_URL ..."
    if [ ! -d "$FEED_DIR" ]; then
        echo "create feed app dir: $FEED_DIR..."
	    mkdir -vp $FEED_DIR
    fi
	
    git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "$GIT_URL" "$FEED_DIR/$PKG_NAME"
    ls $FEED_DIR/$PKG_NAME
	if [ ! -d "$FEED_DIR/$PKG_NAME" ]; then
		echo "ERROR: Failed to clone $PKG_REPO"
		return 1
	fi

	local OLD=$PWD
	cd $FEED_DIR/$PKG_NAME
    local REAL_PATH=$PWD
	echo $REAL_PATH
	cd $OLD
	local SRC_LINK="src-link $PKG_NAME $REAL_PATH"
	echo $SRC_LINK
	echo "$SRC_LINK" >> ../feeds.conf.default
	cat ../feeds.conf.default
	../scripts/feeds update $PKG_NAME
    ../scripts/feeds install -a -p $PKG_NAME
	return 0
}

UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo " "
	echo "=========================================="
	echo "Processing: $PKG_NAME from $PKG_REPO"
	echo "=========================================="

	# 删除 feeds 中可能存在的同名软件包
	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

	if [ ! -d "$REPO_NAME" ]; then
		echo "ERROR: Failed to clone $PKG_REPO"
		return 1
	fi

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		# 从大杂烩仓库中提取特定包
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		# 重命名仓库
		mv -f $REPO_NAME $PKG_NAME
	fi

	echo "Done: $PKG_NAME"
}

UPDATE_PACKAGE "advanced" "kenzok78/luci-app-advanced" "main"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "picoclaw" "GennKann/luci-app-picoclaw" "master"

# soc status app
pkgs=("luci-app-airoha-npu"); UPDATE_PACKAGE pkgs "oyk470p/luci-app-airoha-npu" "main"; unset pkgs
sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' ./luci-app-airoha-npu/Makefile

# 修改 LuCI 默认主题为 Aurora（保留 bootstrap 包可共存）
echo " "
echo "=========================================="
echo "Setting default LuCI theme to Aurora..."
echo "=========================================="
COLLECTION_MAKEFILES=$(find ../feeds/luci/collections/ -type f -name "Makefile" 2>/dev/null)
if [ -n "$COLLECTION_MAKEFILES" ]; then
	sed -i "s/luci-theme-bootstrap/luci-theme-aurora/g" $COLLECTION_MAKEFILES
	echo "Done setting default LuCI theme to aurora"
else
	echo "WARNING: No LuCI collection Makefile found, skip theme default patch"
fi

echo " "
echo "=========================================="
echo "Package updates completed!"
echo "=========================================="
