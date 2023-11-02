extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var camera_2d: Camera2D = $Player/Camera2D


func _ready() -> void:
	# 设置相机可拍摄的范围，直接根据tilemap的使用情况给出，无需手动测量
	# 【注意】要求tilemap的长宽尺寸要大于相机的尺寸，否则必定会出现「出界」的bug！
	# grow(-1) 为什么要向内缩小一格？ 隐藏最外层的边界，给人一种「地图很大」的感觉。
	var used := tile_map.get_used_rect().grow(-1)
	# tile_size 是图块的大小（实际像素=图块数*图块像素数）
	var tile_size := tile_map.tile_set.tile_size

	# used 获取的是 position（左上角）和 end（右下角）的坐标
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y

	# 取消从开始的「出界」到正常视角的过渡动画
	camera_2d.reset_smoothing()
