@tool
@icon("res://ui/assets/icons/动画管理.svg")
extends Node
class_name TweenManager
@export var tween_nodes:Array[TweenNode]
@export var animation_scale:Vector2=Vector2(1.3,1.3)
@export var animation_delay:float=0.1
var _tween_nodes:Array[TweenNode]
func _ready() -> void:
	var all_descendants = get_parent().find_children("*", "", true, false)
	for tween_node in all_descendants:
		if tween_node is TweenNode:
			_tween_nodes.append(tween_node)
	animation_start()
	pass
	
#开始动画
func animation_start():
	var animation_node_array:Array
	for tween_node:TweenNode in _tween_nodes:
		var all_control=tween_node.get_parent().get_children()
		for control in all_control:
			animation_node_array.append(control)
			#if control is Control and tween_node.remove_node!=control:
				#print(control)
	
	for tween_node:TweenNode in _tween_nodes:
		for rn in tween_node.remove_nodes:
			animation_node_array.erase(rn)
	print(animation_node_array)	
		#var node:Control=get_node(tween_node.node_path)
		#for animation_type:TweenNode.ANIMATION_TYPE in tween_node.animation_type:
			#animation(tween_node,animation_type,node,tween_node.duration,index)
		#pass
		#index+=1
	pass
func animation_hover_bind():
	var index=0
	for tween_node:TweenNode in tween_nodes:
		var node:Control=get_node(tween_node.node_path)
		if tween_node.animation_when==TweenNode.ANIMATION_WHEN.HOVER:
			
			node.mouse_entered.connect(func():
				for animtion_type in tween_node.animation_type:
					animation(tween_node,animtion_type,node,tween_node.duration,index)
				pass
			)
		index+=1
	
	pass

func animation_show_bind():
	var index=0
	for tween_node:TweenNode in tween_nodes:
		var node:Control=get_node(tween_node.node_path)
		if tween_node.animation_when==TweenNode.ANIMATION_WHEN.HOVER:
			
			node.visibility_changed.connect(func():
				for animtion_type in tween_node.animation_type:
					animation(tween_node,animtion_type,node,tween_node.duration,index)
				pass
			)
		index+=1
	pass
func animation(tween_node:TweenNode,animation_type:TweenNode.ANIMATION_TYPE,node:Node,duration:float,index):
	var tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	if animation_type==TweenNode.ANIMATION_TYPE.SCALE:
		var _animation_scale=animation_scale
		if tween_node.scale!=Vector2.ZERO:
			_animation_scale=tween_node.scale
			
		tween.tween_property(node,"offset_transform_scale",Vector2.ONE,duration).from(_animation_scale).set_delay(index*animation_delay)
	if animation_type==TweenNode.ANIMATION_TYPE.FADE:
		tween.tween_property(node,"modulate:a",1.0,duration).from(0.0).set_delay(index*animation_delay)
	prints(animation_type,node)
	
