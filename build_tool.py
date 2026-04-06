# -*- coding: utf-8 -*-
"""
Kuaibu Flutter 构建工具
快速执行常用构建操作
"""

import subprocess
import sys
import os

# 项目根目录
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))

# 构建命令配置
BUILD_COMMANDS = {
    "0": {
        "name": "清理项目",
        "cmd": ["flutter", "clean"],
        "desc": "清理构建缓存"
    },
    "1": {
        "name": "打包 Windows Debug",
        "cmd": ["flutter", "build", "windows", "--debug"],
        "desc": "构建 Windows Debug 版本"
    },
    "2": {
        "name": "打包 Windows Release",
        "cmd": ["flutter", "build", "windows", "--release"],
        "desc": "构建 Windows Release 版本"
    },
    "3": {
        "name": "打包 Android Debug",
        "cmd": ["flutter", "build", "apk", "--debug"],
        "desc": "构建 Android Debug APK"
    },
    "4": {
        "name": "打包 Android Release",
        "cmd": ["flutter", "build", "apk", "--release"],
        "desc": "构建 Android Release APK"
    },
    "5": {
        "name": "打包 Android ARM64 Release",
        "cmd": ["flutter", "build", "apk", "--release", "--target-platform=android-arm64"],
        "desc": "构建 Android ARM64 Release APK"
    },
    "6": {
        "name": "打包 Android ARM Release",
        "cmd": ["flutter", "build", "apk", "--release", "--target-platform=android-arm"],
        "desc": "构建 Android ARM Release APK"
    },
    "7": {
        "name": "获取依赖",
        "cmd": ["flutter", "pub", "get"],
        "desc": "获取 Flutter 依赖包"
    },
    "8": {
        "name": "运行项目",
        "cmd": ["flutter", "run"],
        "desc": "运行 Flutter 项目"
    },
    "9": {
        "name": "运行 Windows",
        "cmd": ["flutter", "run", "-d", "windows"],
        "desc": "在 Windows 上运行项目"
    },
}


def print_menu():
    """打印菜单"""
    print("\n" + "=" * 60)
    print("       Kuaibu Flutter 构建工具")
    print("=" * 60)
    print()
    for key, value in sorted(BUILD_COMMANDS.items(), key=lambda x: int(x[0])):
        print(f"  [{key}] {value['name']:<30} - {value['desc']}")
    print()
    print("  [q] 退出程序")
    print()
    print("=" * 60)


def run_command(key):
    """执行命令"""
    if key not in BUILD_COMMANDS:
        print(f"\n❌ 无效的选项: {key}")
        return False

    config = BUILD_COMMANDS[key]
    print(f"\n{'=' * 60}")
    print(f"🚀 开始执行: {config['name']}")
    print(f"📋 命令: {' '.join(config['cmd'])}")
    print(f"{'=' * 60}\n")

    try:
        # 在 Windows 上使用 shell=True 来正确找到 flutter 命令
        use_shell = sys.platform == 'win32'
        
        # 使用 subprocess 执行命令，实时输出
        process = subprocess.Popen(
            ' '.join(config['cmd']) if use_shell else config['cmd'],
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding='utf-8',
            errors='ignore',
            shell=use_shell
        )

        # 实时输出
        for line in process.stdout:
            print(line, end='')

        process.wait()

        if process.returncode == 0:
            print(f"\n{'=' * 60}")
            print(f"✅ 执行成功: {config['name']}")
            print(f"{'=' * 60}")
        else:
            print(f"\n{'=' * 60}")
            print(f"❌ 执行失败 (退出码: {process.returncode}): {config['name']}")
            print(f"{'=' * 60}")

        return process.returncode == 0

    except FileNotFoundError:
        print(f"\n❌ 错误: 找不到 flutter 命令，请确保 Flutter 已安装并添加到 PATH")
        return False
    except Exception as e:
        print(f"\n❌ 执行出错: {e}")
        return False


def main():
    """主函数"""
    # 如果直接传入参数，执行对应命令
    if len(sys.argv) > 1:
        key = sys.argv[1]
        if key == 'q' or key == 'quit':
            print("👋 再见！")
            sys.exit(0)
        if key in BUILD_COMMANDS:
            run_command(key)
        else:
            print(f"❌ 无效的命令: {key}")
            print_menu()
        return

    # 交互模式
    while True:
        print_menu()
        try:
            user_input = input("\n请输入选项 (0-9, q退出): ").strip().lower()

            if user_input in ['q', 'quit', 'exit']:
                print("\n👋 再见！")
                break

            if user_input in BUILD_COMMANDS:
                run_command(user_input)
            else:
                print(f"\n❌ 无效的选项: {user_input}")

            input("\n按回车键继续...")

        except KeyboardInterrupt:
            print("\n\n👋 再见！")
            break
        except EOFError:
            print("\n\n👋 再见！")
            break


if __name__ == "__main__":
    main()
