@icon("res://ui/assets/icons/动画.svg")
extends Node
class_name TweenNode
@export var animation_when:ANIMATION_WHEN
@export var animation_type:ANIMATION_TYPE
@export var order_type:ORDER_TYPE
@export var duration:float=0.3
@export var scale:Vector2
@export var remove_nodes:Array[Control]
enum ANIMATION_TYPE{
	SCALE,
	FADE
}
enum ANIMATION_WHEN{
	START,
	HOVER,
	SHOW
}
enum ORDER_TYPE{
	START_TOP,
	START_BOTTOM
}
