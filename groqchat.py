#!/usr/bin/env python3
"""Simple terminal chatbot using Groq. No Gmail access or automatic email sends."""
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

URL = 'https://api.groq.com/openai/v1/chat/completions'
MODEL = 'llama-3.3-70b-versatile'


def main():
    print('Groq terminal chat. Type /quit to exit, /clear to forget this chat.')
    key = os.environ.get('GROQ_API_KEY') or getpass.getpass('Groq API key (hidden, not saved): ').strip()
    if not key:
        sys.exit('No key entered.')
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
            headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
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
