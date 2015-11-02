/*
 * Torch control sysfs provider driver for Samsung HLTE phones
 *
 * Copyright (c) 2015, jcadduono @ xda-developers.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/types.h>
#include <linux/gpio.h>

#define GPIO_FLASH "max77803_flash_en"
#define GPIO_TORCH "max77803_torch_en"

static int torch_control_level = 0;
static int torch_control_force = 0;

extern int led_flash_en;
extern int led_torch_en;

extern struct class *camera_class;
struct device *torch_device;

int torch_level_set(int force, int level)
{
	if (!force && torch_control_force) {
		dev_info(torch_device, "denying torch level change (enforced %d)\n", torch_control_level);
		return -EPERM;
	}
	if (level == 0) {
		dev_info(torch_device, "turning off torch\n");
		if (gpio_request(led_flash_en, GPIO_FLASH))
			dev_err(torch_device, "gpio request failed for %s\n", GPIO_FLASH);
		else {
			gpio_direction_output(led_flash_en, 0);
			gpio_free(led_flash_en);
		}
		if (gpio_request(led_torch_en, GPIO_TORCH))
			dev_err(torch_device, "gpio request failed for %s\n", GPIO_TORCH);
		else {
			gpio_direction_output(led_torch_en, 0);
			gpio_free(led_torch_en);
		}
		torch_control_level = 0;
	}
	else if (level == 1) {
		if (gpio_request(led_torch_en, GPIO_TORCH))
			dev_err(torch_device, "gpio request failed for %s\n", GPIO_TORCH);
		else {
			dev_info(torch_device, "setting torch brightness to low\n");
			gpio_direction_output(led_torch_en, 1);
			gpio_free(led_torch_en);
		}
		torch_control_level = 1;
	}
	else if (level == 2) {
		if (gpio_request(led_flash_en, GPIO_FLASH))
			dev_err(torch_device, "gpio request failed for %s\n", GPIO_FLASH);
		else {
			dev_info(torch_device, "setting torch brightness to high\n");
			gpio_direction_output(led_flash_en, 1);
			gpio_free(led_flash_en);
		}
		torch_control_level = 2;
	}
	else {
		return -EINVAL;
	}
	return 0;
}
EXPORT_SYMBOL(torch_level_set)

static ssize_t torch_attr_level_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return sprintf(buf, "%d\n", torch_control_level);
}

static ssize_t torch_attr_level_set(struct device *dev, struct device_attribute *attr, const char *buf, size_t size)
{
	torch_level_set(1, simple_strtol(buf, NULL, 10));
	return size;
}

static ssize_t torch_attr_force_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return sprintf(buf, "%d\n", torch_control_force);
}

static ssize_t torch_attr_force_set(struct device *dev, struct device_attribute *attr, const char *buf, size_t size)
{
	int force = simple_strtol(buf, NULL, 10);
	if (force == 1) {
		dev_info(torch_device, "enforcing torch level %d\n", torch_control_level);
		torch_control_force = 1;
	}
	else if (force == 0) {
		dev_info(torch_device, "stopped enforcing torch level\n");
		torch_control_force = 0;
	}
	return size;
}

static DEVICE_ATTR(level, S_IWUGO | S_IRUGO, torch_attr_level_show, torch_attr_level_set);
static DEVICE_ATTR(force, S_IWUGO | S_IRUGO, torch_attr_force_show, torch_attr_force_set);

static ssize_t __init torch_module_init(void)
{
	pr_info("%s: initializing sysfs nodes\n", KBUILD_MODNAME);
	torch_device = device_create(camera_class, NULL, 0, NULL, "torch");
	if (IS_ERR(torch_device)) {
		pr_err("%s: failed to create camera/torch sysfs device!\n", KBUILD_MODNAME);
		return -EIO;
	}
	if (device_create_file(torch_device, &dev_attr_level) < 0)
		dev_err(torch_device, "failed to create camera/torch/level sysfs node!\n");
	if (device_create_file(torch_device, &dev_attr_force) < 0)
		dev_err(torch_device, "failed to create camera/torch/force sysfs node!\n");
	return 0;
}

static void __exit torch_module_exit(void)
{
	device_remove_file(torch_device, &dev_attr_level);
	device_remove_file(torch_device, &dev_attr_force);
}

module_init(torch_module_init);
module_exit(torch_module_exit);

MODULE_AUTHOR("jcadduono");
MODULE_DESCRIPTION("torch control sysfs provider for hlte");
MODULE_VERSION("1.0");
MODULE_LICENSE("Dual MIT/GPL");
