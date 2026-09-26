#!/usr/bin/env python3
"""Simple terminal chatbot using Groq. No Gmail access or automatic email sends."""
import json
import sys
import urllib.error
import urllib.request

URL = 'https://api.groq.com/openai/v1/chat/completions'
MODEL = 'llama-3.3-70b-versatile'
GROQ_API_KEY = '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'  # Put your key between quotes on your Pi. Do not push that edit to GitHub.


def main():
    if GROQ_API_KEY == 'PASTE_KEY_HERE' or not GROQ_API_KEY.strip():
        sys.exit('Open groqchat1.py and replace PASTE_KEY_HERE with your Groq API key first.')
    print('Groq terminal chat. Type /quit to exit, /clear to forget this chat.')
    messages = [{'role': 'system', 'content': 'You are a helpful, concise chatbot. Be honest when unsure.'}]
    while True:
        try:
            question = input('\nYou: ').strip()
        except (KeyboardInterrupt, EOFError):
            print('\nBye!')
            break
        if question.lower() in ('/quit', '/exit'):
            print('Bye!')
            break
        if question.lower() == '/clear':
            messages = messages[:1]
            print('Chat cleared.')
            continue
        if not question:
            continue
        proposed = messages[-18:] + [{'role': 'user', 'content': question[:12000]}]
        data = json.dumps({'model': MODEL, 'messages': proposed, 'temperature': 0.7,
                           'max_completion_tokens': 800}).encode()
        request = urllib.request.Request(URL, data=data,
            headers={'Authorization': 'Bearer ' + GROQ_API_KEY, 'Content-Type': 'application/json',
                     'Accept': 'application/json', 'User-Agent': 'groqchat-pi/1.1'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                result = json.load(response)
            answer = result['choices'][0]['message']['content'] or '(No text returned.)'
            print('\nBot:', answer)
            messages = proposed + [{'role': 'assistant', 'content': answer}]
        except urllib.error.HTTPError as exc:
            detail = exc.read(500).decode('utf-8', 'replace')
            print(f'Groq returned HTTP {exc.code}: {detail}', file=sys.stderr)
        except (urllib.error.URLError, TimeoutError, KeyError, ValueError) as exc:
            print(f'Request failed: {exc}', file=sys.stderr)


if __name__ == '__main__':
    main()
