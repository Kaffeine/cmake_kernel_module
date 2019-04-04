#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <asm/uaccess.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Kaffeine");
MODULE_DESCRIPTION("print to dmesg Linux module.");
MODULE_VERSION("0.1");

#define DEVICE_NAME "userspace_dmesg"

/* Prototypes for device functions */
static int device_open(struct inode *, struct file *);
static int device_release(struct inode *, struct file *);
static ssize_t device_read(struct file *, char *, size_t, loff_t *);
static ssize_t device_write(struct file *, const char *, size_t, loff_t *);

static int major_num;
static int device_open_count = 0;

/* This structure points to all of the device functions */
static struct file_operations file_ops = {
    .read = device_read,
    .write = device_write,
    .open = device_open,
    .release = device_release
};

/* When a process reads from our device, this gets called. */
static ssize_t device_read(struct file *flip, char *buffer, size_t len, loff_t *offset) {
    /* This is a write-only device */
    printk(KERN_ALERT "This operation is not supported.\n");
    return -EINVAL;
}

/* Called when a process tries to write to our device */
static ssize_t device_write(struct file *flip, const char *buffer, size_t len, loff_t *offset) {
    char msg_buffer[256];
    int bytes_read = 0;

    if (len < 1) {
        return -EINVAL;
    }

    if (len > 255) {
        len = 255;
    }
    for (; bytes_read < len; ++bytes_read) {
        get_user(msg_buffer[bytes_read], buffer++);
    }
    if (msg_buffer[bytes_read - 1] == '\n') {
        msg_buffer[bytes_read - 1] = 0;
    } else {
        msg_buffer[bytes_read] = 0;
    }
    printk(KERN_INFO "%s\n", msg_buffer);

    return bytes_read;
}

/* Called when a process opens our device */
static int device_open(struct inode *inode, struct file *file) {
    /* If device is open, return busy */
    if (device_open_count) {
        return -EBUSY;
    }
    device_open_count++;
    try_module_get(THIS_MODULE);
    return 0;
}

/* Called when a process closes our device */
static int device_release(struct inode *inode, struct file *file) {
    /* Decrement the open counter and usage count. Without this, the module would not unload. */
    device_open_count--;
    module_put(THIS_MODULE);
    return 0;
}

static int __init userspace_dmesg_init(void) {
    /* Try to register character device */
    major_num = register_chrdev(0, DEVICE_NAME, &file_ops);
    if (major_num < 0) {
        printk(KERN_ALERT "Could not register device: %d\n", major_num);
        return major_num;
    } else {
        printk(KERN_INFO "userspace_dmesg module loaded with device major number %d\n", major_num);
        return 0;
    }
}

static void __exit userspace_dmesg_exit(void) {
    /* Remember — we have to clean up after ourselves. Unregister the character device. */
    unregister_chrdev(major_num, DEVICE_NAME);
}

/* Register module functions */
module_init(userspace_dmesg_init);
module_exit(userspace_dmesg_exit);
