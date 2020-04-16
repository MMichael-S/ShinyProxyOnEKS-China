use mysql;
create database test;

# 测试表
CREATE TABLE `user_test` (
 `uid` serial COMMENT '自增ID',
 `uname` varchar(20) DEFAULT NULL COMMENT '用户名',
 `create_time` datetime DEFAULT NULL COMMENT '创建时间',
 `age` int(4) DEFAULT NULL COMMENT '年龄',
 PRIMARY KEY (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='千万级数据测试表';

# 清理环境
DELETE FROM user_test;
DROP PROCEDURE `test_user_create`;

# 测试存储过程
delimiter ##
SET AUTOCOMMIT = 0##

CREATE PROCEDURE `test_user_create`()

begin

declare v_cnt decimal (10) default 0 ;

create_start:loop
 insert into user_test values
 (null,'用户1','2010-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户2','2010-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户3','2010-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户4','2010-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户5','2011-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户6','2011-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户7','2011-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户8','2013-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户9','2013-01-01 00:00:00',floor(RAND()*100/2)),
 (null,'用户10','2015-01-01 00:00:00',floor(RAND()*100/2));
commit;

 set v_cnt = v_cnt+10 ;
 if v_cnt = 10000000 then leave create_start;
 end if;

end loop create_start;
end;##

delimiter ;
